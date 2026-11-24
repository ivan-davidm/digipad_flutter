import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Still image shown whenever no video is playing (the original wallpaper).
const String kHomeWallpaperAsset = 'assets/images/background.webp';

class BackgroundVideo {
  const BackgroundVideo(this.asset, {this.cutoff});

  final String asset;

  /// Plays only up to this point (loops/ends here) even if the file is longer.
  final Duration? cutoff;
}

/// Double tap cycles through these in order (1 → 2 → 3 → 1).
const List<BackgroundVideo> kBackgroundVideos = [
  BackgroundVideo(
    'assets/videos/home_background.mp4',
    cutoff: Duration(seconds: 17),
  ),
  BackgroundVideo('assets/videos/home_background_2.mp4'),
  BackgroundVideo('assets/videos/home_background_3.mp4'),
];

/// Selectable repeat intervals (minutes) for the periodic modes.
const List<int> kHomeBackgroundIntervals = [1, 2, 5, 10];

enum HomeBackgroundMode {
  /// Video 1 plays forever (today's behaviour).
  video1Loop,

  /// Video 3 plays forever.
  video3Loop,

  /// Wallpaper; every N minutes video 1 plays once and returns to the wallpaper.
  video1Periodic,

  /// Wallpaper; every N minutes video 3 plays once and returns to the wallpaper.
  video3Periodic,

  /// Wallpaper only.
  still,
}

/// Brief visual hint of what the last gesture did.
enum BackgroundFeedback { none, play, pause, next, still }

/// Thin abstraction over the video backend so the state machine can be tested
/// without a real decoder.
abstract class BackgroundPlayer {
  Future<void> initialize();
  Duration get duration;
  Size get size;
  Future<Duration> get position;
  Future<void> play();
  Future<void> pause();
  Future<void> seekToStart();
  Widget buildView();
  Future<void> dispose();
}

typedef BackgroundPlayerFactory = BackgroundPlayer Function(String asset);

class VideoPlayerBackgroundPlayer implements BackgroundPlayer {
  VideoPlayerBackgroundPlayer(String asset)
    : _controller = VideoPlayerController.asset(asset);

  final VideoPlayerController _controller;

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setVolume(0);
    // Looping/ending is driven by HomeBackgroundController so it can honour
    // per-video cut-offs and return to the still wallpaper.
    await _controller.setLooping(false);
  }

  @override
  Duration get duration => _controller.value.duration;

  @override
  Size get size => _controller.value.size;

  @override
  Future<Duration> get position async =>
      await _controller.position ?? Duration.zero;

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekToStart() => _controller.seekTo(Duration.zero);

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();
}

/// Drives the home screen background: wallpaper image + (optional) video.
///
/// Gestures (wired by [HomeBackground]):
///  * tap          → pause / resume the video (if the wallpaper is showing, plays)
///  * double tap   → next video
///  * long press   → show only the wallpaper (long press again resumes)
///
/// The wallpaper is always rendered underneath; the video fades in on top and
/// fades out when it ends, so the screen never freezes on the last frame.
class HomeBackgroundController extends ChangeNotifier {
  HomeBackgroundController({BackgroundPlayerFactory? playerFactory})
    : _playerFactory =
          playerFactory ?? ((asset) => VideoPlayerBackgroundPlayer(asset));

  static const String _kModeKey = 'home_bg_mode';
  static const String _kIntervalKey = 'home_bg_interval_min';

  final BackgroundPlayerFactory _playerFactory;

  HomeBackgroundMode _mode = HomeBackgroundMode.video1Loop;
  int _intervalMinutes = 2;
  int _videoIndex = 0;

  BackgroundPlayer? _player;
  String? _playerAsset;

  bool _videoVisible = false;
  bool _paused = false;
  bool _stillOverride = false;
  bool _loop = true;
  bool _appPaused = false;
  bool _disposed = false;

  /// Bumped on every state change that invalidates in-flight async work.
  int _token = 0;
  Timer? _endTimer;
  Timer? _periodTimer;

  BackgroundFeedback _feedback = BackgroundFeedback.none;
  int _feedbackSerial = 0;

  // ── Public state ──────────────────────────────────────────────────────────

  HomeBackgroundMode get mode => _mode;
  int get intervalMinutes => _intervalMinutes;
  int get videoIndex => _videoIndex;
  BackgroundPlayer? get player => _player;
  bool get videoVisible => _videoVisible;
  bool get isPaused => _paused;
  bool get isStillOverride => _stillOverride;
  BackgroundFeedback get feedback => _feedback;
  int get feedbackSerial => _feedbackSerial;

  bool get _isLoopMode =>
      _mode == HomeBackgroundMode.video1Loop ||
      _mode == HomeBackgroundMode.video3Loop;

  bool get isPeriodicMode =>
      _mode == HomeBackgroundMode.video1Periodic ||
      _mode == HomeBackgroundMode.video3Periodic;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_kModeKey);
      _mode = HomeBackgroundMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => HomeBackgroundMode.video1Loop,
      );
      final minutes = prefs.getInt(_kIntervalKey);
      if (minutes != null && kHomeBackgroundIntervals.contains(minutes)) {
        _intervalMinutes = minutes;
      }
    } catch (e) {
      debugPrint('[HomeBackground] could not load prefs: $e');
    }
    if (_disposed) return;
    _videoIndex = _videoIndexFor(_mode) ?? 0;
    notifyListeners();
    await _applyMode(preview: false);
  }

  void onAppPaused() {
    _appPaused = true;
    if (_videoVisible && !_paused) {
      _endTimer?.cancel();
      unawaited(_player?.pause());
    }
  }

  void onAppResumed() {
    _appPaused = false;
    if (_videoVisible && !_paused && !_stillOverride) {
      unawaited(_player?.play());
      unawaited(_armEndTimer(_token));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    _cancelTimers();
    final player = _player;
    _player = null;
    if (player != null) unawaited(_safeDispose(player));
    super.dispose();
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  Future<void> onTap() async {
    if (_disposed) return;
    final showingVideo = _videoVisible && !_stillOverride && _player != null;
    if (!showingVideo) {
      _setFeedback(BackgroundFeedback.play);
      await _play(loop: _isLoopMode);
      return;
    }
    final player = _player!;
    if (_paused) {
      _paused = false;
      _setFeedback(BackgroundFeedback.play);
      await _safePlay(player);
      await _armEndTimer(_token);
    } else {
      // Freeze on the current frame: the video stays visible, only paused.
      _paused = true;
      _endTimer?.cancel();
      _setFeedback(BackgroundFeedback.pause);
      await _safePause(player);
    }
  }

  Future<void> onDoubleTap() async {
    if (_disposed) return;
    _videoIndex = (_videoIndex + 1) % kBackgroundVideos.length;
    _setFeedback(BackgroundFeedback.next);
    await _play(loop: _isLoopMode);
  }

  Future<void> onLongPress() async {
    if (_disposed) return;
    if (_stillOverride) {
      // Resume according to the configured mode.
      _stillOverride = false;
      _setFeedback(BackgroundFeedback.play);
      if (_isLoopMode) {
        await _play(loop: true);
      } else if (isPeriodicMode) {
        _schedulePeriod();
      }
      return;
    }
    _stillOverride = true;
    _token++;
    _cancelTimers();
    _videoVisible = false;
    _paused = false;
    _setFeedback(BackgroundFeedback.still);
    await _player?.pause();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> setMode(HomeBackgroundMode mode) async {
    if (_disposed) return;
    _mode = mode;
    final index = _videoIndexFor(mode);
    if (index != null) _videoIndex = index;
    notifyListeners();
    await _persist();
    // Periodic modes play once right away so the operator sees what they picked.
    await _applyMode(preview: isPeriodicMode);
  }

  Future<void> setIntervalMinutes(int minutes) async {
    if (_disposed || !kHomeBackgroundIntervals.contains(minutes)) return;
    _intervalMinutes = minutes;
    notifyListeners();
    await _persist();
    if (isPeriodicMode && !_videoVisible && !_stillOverride) {
      _schedulePeriod();
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  int? _videoIndexFor(HomeBackgroundMode mode) {
    switch (mode) {
      case HomeBackgroundMode.video1Loop:
      case HomeBackgroundMode.video1Periodic:
        return 0;
      case HomeBackgroundMode.video3Loop:
      case HomeBackgroundMode.video3Periodic:
        return 2;
      case HomeBackgroundMode.still:
        return null;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, _mode.name);
      await prefs.setInt(_kIntervalKey, _intervalMinutes);
    } catch (e) {
      debugPrint('[HomeBackground] could not save prefs: $e');
    }
  }

  Future<void> _applyMode({required bool preview}) async {
    _cancelTimers();
    _stillOverride = false;
    _paused = false;
    switch (_mode) {
      case HomeBackgroundMode.video1Loop:
      case HomeBackgroundMode.video3Loop:
        await _play(loop: true);
        break;
      case HomeBackgroundMode.video1Periodic:
      case HomeBackgroundMode.video3Periodic:
        if (preview) {
          await _play(loop: false);
        } else {
          _showWallpaper();
          _schedulePeriod();
        }
        break;
      case HomeBackgroundMode.still:
        _showWallpaper();
        break;
    }
  }

  void _showWallpaper() {
    _token++;
    _videoVisible = false;
    _paused = false;
    unawaited(_player?.pause());
    notifyListeners();
  }

  /// Plays the currently selected video from the start. When [loop] is false
  /// it plays once, fades back to the wallpaper, and (periodic mode) schedules
  /// the next run.
  Future<void> _play({required bool loop}) async {
    if (_disposed) return;
    final token = ++_token;
    _cancelTimers();
    _stillOverride = false;
    _paused = false;
    _loop = loop;
    final video = kBackgroundVideos[_videoIndex];

    BackgroundPlayer player;
    if (_player != null && _playerAsset == video.asset) {
      player = _player!;
      await player.seekToStart();
    } else {
      // Free the current decoder BEFORE opening the next one. Tótem-class
      // devices often have a single usable hardware decoder for 1080p H.264:
      // opening video 2 while video 1 was still alive failed or hung there, so
      // double tap never switched (and video 2 was never seen).
      final previous = _player;
      if (previous != null) {
        _player = null;
        _playerAsset = null;
        _videoVisible = false;
        notifyListeners(); // drop the VideoPlayer widget before disposing
        await _safePause(previous);
        await _safeDispose(previous);
        if (token != _token || _disposed) return;
      }
      final next = _playerFactory(video.asset);
      try {
        await next.initialize();
      } catch (e) {
        // Some low-end devices lack a usable decoder: keep the wallpaper.
        debugPrint('[HomeBackground] could not start ${video.asset}: $e');
        await _safeDispose(next);
        if (token == _token && !_disposed) {
          _videoVisible = false;
          notifyListeners();
        }
        return;
      }
      if (token != _token || _disposed) {
        await _safeDispose(next);
        return;
      }
      _player = next;
      _playerAsset = video.asset;
      player = next;
    }
    if (token != _token || _disposed) return;

    await player.play();
    if (token != _token || _disposed) return;

    _videoVisible = true;
    notifyListeners();
    await _armEndTimer(token);
  }

  Duration _endOf(BackgroundVideo video, BackgroundPlayer player) {
    final duration = player.duration;
    final cutoff = video.cutoff;
    return (cutoff != null && cutoff < duration) ? cutoff : duration;
  }

  Future<void> _armEndTimer(int token) async {
    _endTimer?.cancel();
    final player = _player;
    if (player == null) return;
    final end = _endOf(kBackgroundVideos[_videoIndex], player);
    Duration position;
    try {
      position = await player.position;
    } catch (_) {
      position = Duration.zero;
    }
    if (token != _token || _disposed || _paused || _appPaused) return;
    var remaining = end - position;
    if (remaining < const Duration(milliseconds: 100)) {
      remaining = const Duration(milliseconds: 100);
    }
    _endTimer = Timer(remaining, () => _onVideoEnd(token));
  }

  Future<void> _onVideoEnd(int token) async {
    if (token != _token || _disposed) return;
    final player = _player;
    if (player == null) return;
    if (_loop) {
      await player.seekToStart();
      if (token != _token || _disposed) return;
      await player.play();
      await _armEndTimer(token);
      return;
    }
    // Played once: fade back to the wallpaper instead of freezing on the last
    // frame. The next _play() seeks back to the start.
    _videoVisible = false;
    _paused = false;
    notifyListeners();
    await player.pause();
    if (token != _token || _disposed) return;
    if (isPeriodicMode) _schedulePeriod();
  }

  void _schedulePeriod() {
    _periodTimer?.cancel();
    _periodTimer = Timer(Duration(minutes: _intervalMinutes), () {
      if (_disposed) return;
      if (_stillOverride || _appPaused || !isPeriodicMode) {
        if (isPeriodicMode) _schedulePeriod();
        return;
      }
      _play(loop: false);
    });
  }

  void _cancelTimers() {
    _endTimer?.cancel();
    _endTimer = null;
    _periodTimer?.cancel();
    _periodTimer = null;
  }

  void _setFeedback(BackgroundFeedback feedback) {
    _feedback = feedback;
    _feedbackSerial++;
    notifyListeners();
  }

  Future<void> _safePlay(BackgroundPlayer player) async {
    try {
      await player.play();
    } catch (e) {
      debugPrint('[HomeBackground] play failed: $e');
    }
  }

  Future<void> _safePause(BackgroundPlayer player) async {
    try {
      await player.pause();
    } catch (e) {
      debugPrint('[HomeBackground] pause failed: $e');
    }
  }

  Future<void> _safeDispose(BackgroundPlayer player) async {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
