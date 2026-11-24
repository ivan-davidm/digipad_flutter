import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:digipad_flutter/screens/home/home_background_controller.dart';
import 'package:flutter/material.dart';

/// Full-bleed home background: the wallpaper, with the video fading in on top.
/// Taps on empty areas are handled here (module cards sit above and keep their
/// own taps).
class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.controller});

  final HomeBackgroundController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.onTap,
      onDoubleTap: controller.onDoubleTap,
      onLongPress: controller.onLongPress,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final player = controller.player;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Image.asset(
                kHomeWallpaperAsset,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              if (player != null)
                AnimatedOpacity(
                  opacity: controller.videoVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: _VideoLayer(player: player),
                ),
              _GestureFeedback(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

/// Video scaled to cover the screen (no letterboxing, any aspect ratio).
class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.player});

  final BackgroundPlayer player;

  @override
  Widget build(BuildContext context) {
    final size = player.size;
    if (size.isEmpty) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: player.buildView(),
        ),
      ),
    );
  }
}

/// Brief play / pause / next / image icon in the middle of the screen.
class _GestureFeedback extends StatefulWidget {
  const _GestureFeedback({required this.controller});

  final HomeBackgroundController controller;

  @override
  State<_GestureFeedback> createState() => _GestureFeedbackState();
}

class _GestureFeedbackState extends State<_GestureFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _lastSerial = 0;

  @override
  void initState() {
    super.initState();
    _lastSerial = widget.controller.feedbackSerial;
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    final serial = widget.controller.feedbackSerial;
    if (serial != _lastSerial) {
      _lastSerial = serial;
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _anim.dispose();
    super.dispose();
  }

  IconData? _icon(BackgroundFeedback feedback) {
    switch (feedback) {
      case BackgroundFeedback.play:
        return Icons.play_arrow_rounded;
      case BackgroundFeedback.pause:
        return Icons.pause_rounded;
      case BackgroundFeedback.next:
        return Icons.skip_next_rounded;
      case BackgroundFeedback.still:
        return Icons.image_outlined;
      case BackgroundFeedback.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon(widget.controller.feedback);
    if (icon == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value;
            final opacity = t < 0.15 ? t / 0.15 : (1 - t) / 0.85;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + 0.4 * t,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 48),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Settings sheet ─────────────────────────────────────────────────────────

Future<void> showHomeBackgroundSheet(
  BuildContext context,
  HomeBackgroundController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121212),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HomeBackgroundSheet(controller: controller),
  );
}

class _HomeBackgroundSheet extends StatelessWidget {
  const _HomeBackgroundSheet({required this.controller});

  final HomeBackgroundController controller;

  static const _modes = HomeBackgroundMode.values;

  String _label(BuildContext context, HomeBackgroundMode mode) {
    final l10n = context.l10n;
    switch (mode) {
      case HomeBackgroundMode.video1Loop:
        return l10n.homeBgModeVideo1Loop;
      case HomeBackgroundMode.video3Loop:
        return l10n.homeBgModeVideo3Loop;
      case HomeBackgroundMode.video1Periodic:
        return l10n.homeBgModeVideo1Periodic;
      case HomeBackgroundMode.video3Periodic:
        return l10n.homeBgModeVideo3Periodic;
      case HomeBackgroundMode.still:
        return l10n.homeBgModeStill;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.homeBgTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final mode in _modes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      _label(context, mode),
                      style: TextStyle(
                        color: mode == controller.mode
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: mode == controller.mode
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: mode == controller.mode
                        ? const Icon(Icons.check_circle, color: accent)
                        : const Icon(
                            Icons.circle_outlined,
                            color: Colors.white24,
                          ),
                    onTap: () => controller.setMode(mode),
                  ),
                if (controller.isPeriodicMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.homeBgInterval,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in kHomeBackgroundIntervals)
                        ChoiceChip(
                          label: Text('$minutes min'),
                          selected: controller.intervalMinutes == minutes,
                          selectedColor: accent.withValues(alpha: 0.35),
                          backgroundColor: Colors.white10,
                          labelStyle: const TextStyle(color: Colors.white),
                          onSelected: (_) =>
                              controller.setIntervalMinutes(minutes),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.homeBgGestures,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
