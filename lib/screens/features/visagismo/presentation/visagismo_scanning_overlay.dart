import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'visagismo_frame_guide.dart';

/// FaceID-style scan effect shown over the frozen capture while face
/// detection + classification run in the background. Purely decorative —
/// the real work happens in `VisagismoCubit._classify`, gated to run for at
/// least as long as this plays (see `_kMinScanDuration`) so it never looks
/// like a glitch.
class VisagismoScanningOverlay extends StatefulWidget {
  const VisagismoScanningOverlay({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<VisagismoScanningOverlay> createState() =>
      _VisagismoScanningOverlayState();
}

class _VisagismoScanningOverlayState extends State<VisagismoScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ScanPoint> _points;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    final random = math.Random(42);
    _points = List.generate(
      110,
      (_) => _ScanPoint(
        dx: random.nextDouble(),
        dy: random.nextDouble(),
        phase: random.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(widget.imagePath), fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        // Confined to the same frame the capture screen outlined the face
        // with — clipped so the scan line/dots never spill past it onto the
        // rest of the screen.
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kFaceGuideBorderRadius),
            child: SizedBox(
              width: kFaceGuideWidth,
              height: kFaceGuideHeight,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ScanPainter(
                    progress: _controller.value,
                    points: _points,
                  ),
                  size: const Size(kFaceGuideWidth, kFaceGuideHeight),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 56,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Analizando rostro…',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanPoint {
  const _ScanPoint({required this.dx, required this.dy, required this.phase});

  /// Normalized (0..1) position within the canvas.
  final double dx;
  final double dy;

  /// Offsets this point's twinkle cycle from the others so they don't all
  /// flash in sync.
  final double phase;
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({required this.progress, required this.points});

  final double progress;
  final List<_ScanPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final lineY = size.height * progress;

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.deepPurpleAccent.withValues(alpha: 0.0),
          Colors.deepPurpleAccent.withValues(alpha: 0.35),
          Colors.deepPurpleAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, lineY - 45, size.width, 90));
    canvas.drawRect(Rect.fromLTWH(0, lineY - 45, size.width, 90), glowPaint);

    final linePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), linePaint);

    final dotPaint = Paint();
    for (final point in points) {
      final t = (progress + point.phase) % 1.0;
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      if (opacity <= 0.05) continue;
      dotPaint.color = Colors.greenAccent.withValues(alpha: opacity * 0.9);
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        1.4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) => true;
}
