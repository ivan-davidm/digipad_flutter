import 'dart:ui';

import 'package:digipad_flutter/screens/home/home_background_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements BackgroundPlayer {
  FakePlayer(this.asset, {this.length = const Duration(seconds: 20)});

  final String asset;
  final Duration length;

  bool playing = false;
  bool disposed = false;
  bool failInit = false;
  int seekToStartCalls = 0;
  int playCalls = 0;

  @override
  Future<void> initialize() async {
    if (failInit) throw StateError('no decoder');
  }

  @override
  Duration get duration => length;

  @override
  Size get size => const Size(1080, 1920);

  // The fake clock doesn't move the playhead; every (re)start begins at 0.
  @override
  Future<Duration> get position async => Duration.zero;

  @override
  Future<void> play() async {
    playing = true;
    playCalls++;
  }

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> seekToStart() async => seekToStartCalls++;

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<void> dispose() async => disposed = true;
}

class Harness {
  final List<FakePlayer> created = [];
  bool failInit = false;
  late final HomeBackgroundController controller = HomeBackgroundController(
    playerFactory: (asset) {
      final p = FakePlayer(asset)..failInit = failInit;
      created.add(p);
      return p;
    },
  );

  FakePlayer get current =>
      created.lastWhere((p) => p.asset == kBackgroundVideos[controller.videoIndex].asset);
}

Future<Harness> start(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool failInit = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final h = Harness()..failInit = failInit;
  await h.controller.init();
  await tester.pump();
  return h;
}

Future<void> finish(WidgetTester tester, Harness h) async {
  h.controller.dispose();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const v1 = 'assets/videos/home_background.mp4';
  const v2 = 'assets/videos/home_background_2.mp4';
  const v3 = 'assets/videos/home_background_3.mp4';

  testWidgets('defaults to video 1 playing in a loop (today\'s behaviour)',
      (tester) async {
    final h = await start(tester);

    expect(h.controller.mode, HomeBackgroundMode.video1Loop);
    expect(h.controller.videoVisible, isTrue);
    expect(h.created.single.asset, v1);
    expect(h.created.single.playing, isTrue);
    await finish(tester, h);
  });

  testWidgets('video 1 is cut at 17 s and loops (file is longer)',
      (tester) async {
    final h = await start(tester);
    final p = h.created.single;

    await tester.pump(const Duration(seconds: 16));
    expect(p.seekToStartCalls, 0);

    await tester.pump(const Duration(seconds: 2)); // t = 18 s > 17 s
    expect(p.seekToStartCalls, 1);
    expect(p.playing, isTrue);
    expect(h.controller.videoVisible, isTrue);
    await finish(tester, h);
  });

  testWidgets('periodic mode: wallpaper, plays once every N min, then back',
      (tester) async {
    final h = await start(tester, prefs: {
      'home_bg_mode': 'video1Periodic',
      'home_bg_interval_min': 2,
    });

    // Starts on the wallpaper, no decoder spun up yet.
    expect(h.controller.videoVisible, isFalse);
    expect(h.created, isEmpty);

    await tester.pump(const Duration(minutes: 1, seconds: 59));
    expect(h.controller.videoVisible, isFalse);

    await tester.pump(const Duration(seconds: 2)); // 2 min reached
    expect(h.controller.videoVisible, isTrue);
    expect(h.created.single.playing, isTrue);

    // 17 s later it ends and goes back to the wallpaper (not the last frame).
    await tester.pump(const Duration(seconds: 18));
    expect(h.controller.videoVisible, isFalse);
    expect(h.created.single.playing, isFalse);

    // …and runs again 2 min after that.
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    expect(h.controller.videoVisible, isTrue);
    await finish(tester, h);
  });

  testWidgets('tap pauses and resumes', (tester) async {
    final h = await start(tester);
    final p = h.created.single;

    await h.controller.onTap();
    expect(h.controller.isPaused, isTrue);
    expect(p.playing, isFalse);
    expect(h.controller.videoVisible, isTrue, reason: 'paused keeps the frame');

    await h.controller.onTap();
    expect(h.controller.isPaused, isFalse);
    expect(p.playing, isTrue);
    await finish(tester, h);
  });

  testWidgets('pausing stops the 17 s cut-off from firing', (tester) async {
    final h = await start(tester);
    final p = h.created.single;

    await h.controller.onTap(); // pause
    await tester.pump(const Duration(seconds: 30));
    expect(p.seekToStartCalls, 0);
    await finish(tester, h);
  });

  testWidgets('double tap cycles video 1 -> 2 -> 3 -> 1', (tester) async {
    final h = await start(tester);

    await h.controller.onDoubleTap();
    expect(h.controller.videoIndex, 1);
    expect(h.current.asset, v2);
    expect(h.current.playing, isTrue);

    await h.controller.onDoubleTap();
    expect(h.current.asset, v3);

    await h.controller.onDoubleTap();
    expect(h.current.asset, v1);

    // Replaced controllers are released shortly after the swap.
    await tester.pump(const Duration(seconds: 1));
    expect(h.created.where((p) => p.disposed), isNotEmpty);
    await finish(tester, h);
  });

  testWidgets('long press shows only the wallpaper; tap plays again',
      (tester) async {
    final h = await start(tester);
    final p = h.created.single;

    await h.controller.onLongPress();
    expect(h.controller.videoVisible, isFalse);
    expect(h.controller.isStillOverride, isTrue);
    expect(p.playing, isFalse);

    await tester.pump(const Duration(minutes: 5));
    expect(h.controller.videoVisible, isFalse, reason: 'stays on the image');

    await h.controller.onTap();
    expect(h.controller.videoVisible, isTrue);
    expect(h.controller.isStillOverride, isFalse);
    expect(h.current.playing, isTrue);
    await finish(tester, h);
  });

  testWidgets('second long press resumes according to the mode',
      (tester) async {
    final h = await start(tester);

    await h.controller.onLongPress();
    await h.controller.onLongPress();

    expect(h.controller.isStillOverride, isFalse);
    expect(h.controller.videoVisible, isTrue);
    expect(h.current.playing, isTrue);
    await finish(tester, h);
  });

  testWidgets('long press blocks the periodic timer', (tester) async {
    final h = await start(tester, prefs: {'home_bg_mode': 'video3Periodic'});

    await h.controller.onLongPress();
    await tester.pump(const Duration(minutes: 10));
    expect(h.controller.videoVisible, isFalse);
    expect(h.created, isEmpty);

    await h.controller.onLongPress(); // resume → timer armed again
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    expect(h.controller.videoVisible, isTrue);
    expect(h.current.asset, v3);
    await finish(tester, h);
  });

  testWidgets('setMode switches video, persists, and previews periodic modes',
      (tester) async {
    final h = await start(tester);

    await h.controller.setMode(HomeBackgroundMode.video3Loop);
    expect(h.current.asset, v3);
    expect(h.controller.videoVisible, isTrue);

    await h.controller.setMode(HomeBackgroundMode.still);
    expect(h.controller.videoVisible, isFalse);

    await h.controller.setMode(HomeBackgroundMode.video3Periodic);
    expect(h.controller.videoVisible, isTrue, reason: 'plays once as preview');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('home_bg_mode'), 'video3Periodic');

    await tester.pump(const Duration(seconds: 21)); // preview ends
    expect(h.controller.videoVisible, isFalse);
    await finish(tester, h);
  });

  testWidgets('changing the interval re-arms the periodic timer',
      (tester) async {
    final h = await start(tester, prefs: {
      'home_bg_mode': 'video1Periodic',
      'home_bg_interval_min': 2,
    });

    await h.controller.setIntervalMinutes(5);
    await tester.pump(const Duration(minutes: 3));
    expect(h.controller.videoVisible, isFalse);

    await tester.pump(const Duration(minutes: 2, seconds: 1));
    expect(h.controller.videoVisible, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('home_bg_interval_min'), 5);
    await finish(tester, h);
  });

  testWidgets('a device with no usable decoder keeps the wallpaper',
      (tester) async {
    final h = await start(tester, failInit: true);

    expect(h.controller.videoVisible, isFalse);
    expect(h.controller.player, isNull);
    // Gestures must not blow up either.
    await h.controller.onTap();
    await h.controller.onDoubleTap();
    expect(h.controller.videoVisible, isFalse);
    await finish(tester, h);
  });

  testWidgets('backgrounding the app pauses the video; resuming restarts it',
      (tester) async {
    final h = await start(tester);
    final p = h.created.single;

    h.controller.onAppPaused();
    await tester.pump();
    expect(p.playing, isFalse);

    h.controller.onAppResumed();
    await tester.pump();
    expect(p.playing, isTrue);
    await finish(tester, h);
  });

  testWidgets('unknown/garbage stored values fall back to defaults',
      (tester) async {
    final h = await start(tester, prefs: {
      'home_bg_mode': 'nonsense',
      'home_bg_interval_min': 7,
    });

    expect(h.controller.mode, HomeBackgroundMode.video1Loop);
    expect(h.controller.intervalMinutes, 2);
    await finish(tester, h);
  });
}
