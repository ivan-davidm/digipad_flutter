// Generates the generic frame illustrations used by the visagismo catalog:
// one transparent 1200x800 PNG per frame tag, all drawn in the same style and
// scaled to the same visual width, so they look like one consistent set.
//
// Run from the repo root (it needs the Flutter engine, hence `flutter test`):
//
//   flutter test tool/generate_frame_illustrations.dart
//
// Output: assets/images/visagismo/frames/<tag>.png
// Optionally also writes a contact sheet if FRAME_SHEET_PATH is set.
//
// The illustrations are original vector drawings (no third-party artwork, so
// no licence to track). To restyle them, tweak the specs below and re-run, then
// copy the PNGs to `digipad_totem/assets/images/visagismo/frames/`.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int kW = 1200;
const int kH = 800;

/// Visual size every illustration is scaled to fit (leaves a small margin).
const double kFitW = 1090;
const double kFitH = 520;

const Color kAcetate = Color(0xFF23262F);
const Color kWire = Color(0xFF5C6472);

typedef LensBuilder = Path Function(Rect r);

class FrameSpec {
  const FrameSpec({
    required this.tag,
    required this.lensW,
    required this.lensH,
    required this.gap,
    required this.lens,
    required this.rim,
    this.color = kAcetate,
    this.bridgeY = 0.30,
    this.bridgeArch = 28,
    this.bridgeW,
    this.templeLen = 70,
    this.templeW,
    this.rimless = false,
    this.browBar = false,
  });

  final String tag;
  final double lensW;
  final double lensH;

  /// Distance between the two lenses' inner edges.
  final double gap;
  final LensBuilder lens;

  /// Rim thickness (0 for rimless).
  final double rim;
  final Color color;

  /// Where the bridge leaves the lens inner edge, as a fraction of lens height.
  final double bridgeY;

  /// How much the bridge bows upwards.
  final double bridgeArch;
  final double? bridgeW;
  final double templeLen;
  final double? templeW;
  final bool rimless;

  /// Aviator-style second bar across the top.
  final bool browBar;
}

// ── Lens shapes (left lens; the right one is its mirror image) ─────────────

Path oval(Rect r) => Path()..addOval(r);

Path roundRect(Rect r, double radiusFraction) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * radiusFraction)),
  );

/// Upswept outer corner. [lift] 0 = barely, 1 = pronounced.
Path catEye(Rect r, double lift) {
  double x(double t) => r.left + r.width * t;
  double y(double t) => r.top + r.height * t;
  final tipY = -0.14 * lift;
  return Path()
    ..moveTo(x(0.0), y(tipY))
    ..cubicTo(x(0.32), y(tipY + 0.04), x(0.74), y(0.0), x(0.98), y(0.12))
    ..cubicTo(x(1.03), y(0.36), x(1.00), y(0.78), x(0.82), y(0.94))
    ..cubicTo(x(0.62), y(1.06), x(0.30), y(1.04), x(0.13), y(0.86))
    ..cubicTo(x(0.00), y(0.66), x(-0.02), y(0.30), x(0.0), y(tipY))
    ..close();
}

/// Soft wayfarer: wider, flatter top; rounded lower half.
Path wayfarer(Rect r) {
  double x(double t) => r.left + r.width * t;
  double y(double t) => r.top + r.height * t;
  return Path()
    ..moveTo(x(0.04), y(0.14))
    ..cubicTo(x(0.30), y(-0.03), x(0.72), y(-0.03), x(0.98), y(0.12))
    ..cubicTo(x(1.02), y(0.36), x(0.98), y(0.70), x(0.84), y(0.88))
    ..cubicTo(x(0.70), y(1.03), x(0.30), y(1.05), x(0.14), y(0.90))
    ..cubicTo(x(0.02), y(0.74), x(-0.02), y(0.36), x(0.04), y(0.14))
    ..close();
}

/// Aviator / teardrop: narrower at the top, widest and roundest at the bottom.
Path teardrop(Rect r) {
  double x(double t) => r.left + r.width * t;
  double y(double t) => r.top + r.height * t;
  return Path()
    ..moveTo(x(0.14), y(0.0))
    ..cubicTo(x(0.40), y(-0.03), x(0.70), y(-0.03), x(0.94), y(0.0))
    ..cubicTo(x(1.00), y(0.22), x(1.02), y(0.55), x(0.96), y(0.74))
    ..cubicTo(x(0.88), y(0.98), x(0.62), y(1.04), x(0.40), y(1.02))
    ..cubicTo(x(0.16), y(1.00), x(0.00), y(0.82), x(0.00), y(0.60))
    ..cubicTo(x(0.00), y(0.34), x(0.07), y(0.12), x(0.14), y(0.0))
    ..close();
}

final List<FrameSpec> kSpecs = [
  // Round, bold acetate.
  FrameSpec(
    tag: 'redondo',
    lensW: 400,
    lensH: 400,
    gap: 96,
    lens: oval,
    rim: 44,
    bridgeArch: 30,
  ),
  // Thin wire circles.
  FrameSpec(
    tag: 'circular',
    lensW: 350,
    lensH: 350,
    gap: 84,
    lens: oval,
    rim: 11,
    color: kWire,
    bridgeY: 0.34,
    bridgeArch: 36,
    templeLen: 80,
  ),
  // Bold rounded square.
  FrameSpec(
    tag: 'cuadrado',
    lensW: 420,
    lensH: 330,
    gap: 92,
    lens: (r) => roundRect(r, 0.09),
    rim: 40,
    bridgeArch: 24,
  ),
  // Wide, shallow rectangle, medium rim.
  FrameSpec(
    tag: 'rectangular',
    lensW: 440,
    lensH: 290,
    gap: 82,
    lens: (r) => roundRect(r, 0.12),
    rim: 24,
    bridgeY: 0.28,
    bridgeArch: 22,
  ),
  // Pronounced cat-eye, bold acetate.
  FrameSpec(
    tag: 'cat_eye',
    lensW: 420,
    lensH: 330,
    gap: 84,
    lens: (r) => catEye(r, 1.0),
    rim: 36,
    bridgeY: 0.36,
    bridgeArch: 24,
  ),
  // Gentle cat-eye, thinner rim.
  FrameSpec(
    tag: 'cat_eye_suave',
    lensW: 420,
    lensH: 320,
    gap: 80,
    lens: (r) => catEye(r, 0.45),
    rim: 18,
    bridgeY: 0.34,
    bridgeArch: 24,
  ),
  // Oval.
  FrameSpec(
    tag: 'ovalado',
    lensW: 420,
    lensH: 310,
    gap: 82,
    lens: oval,
    rim: 22,
    bridgeY: 0.32,
    bridgeArch: 26,
  ),
  // Soft curved wayfarer.
  FrameSpec(
    tag: 'curvo',
    lensW: 420,
    lensH: 330,
    gap: 84,
    lens: wayfarer,
    rim: 34,
    bridgeY: 0.26,
    bridgeArch: 22,
  ),
  // Tall lenses.
  FrameSpec(
    tag: 'lente_alto',
    lensW: 300,
    lensH: 410,
    gap: 92,
    lens: (r) => roundRect(r, 0.34),
    rim: 20,
    bridgeY: 0.30,
  ),
  // Very large, bold.
  FrameSpec(
    tag: 'oversize',
    lensW: 470,
    lensH: 430,
    gap: 74,
    lens: (r) => roundRect(r, 0.42),
    rim: 30,
    bridgeArch: 18,
  ),
  // No rim: lenses held by screws, thin metal bridge and temples.
  FrameSpec(
    tag: 'rimless',
    lensW: 420,
    lensH: 330,
    gap: 62,
    lens: (r) => roundRect(r, 0.28),
    rim: 0,
    color: kWire,
    rimless: true,
    bridgeY: 0.24,
    bridgeArch: 20,
    bridgeW: 7,
    templeLen: 62,
    templeW: 7,
  ),
  // Aviator: widest at the bottom, thin metal, double bar.
  FrameSpec(
    tag: 'ancho_abajo',
    lensW: 420,
    lensH: 400,
    gap: 70,
    lens: teardrop,
    rim: 10,
    color: kWire,
    browBar: true,
    bridgeY: 0.20,
    bridgeArch: 18,
    templeLen: 78,
  ),
];

// ── Painting ────────────────────────────────────────────────────────────────

/// Point of [path]'s outline at height [y]: the innermost (largest x) or the
/// outermost (smallest x) one.
Offset _edgePoint(Path path, double y, {required bool innermost}) {
  Offset? best;
  for (final metric in path.computeMetrics()) {
    for (double d = 0; d <= metric.length; d += 1.0) {
      final p = metric.getTangentForOffset(d)!.position;
      if ((p.dy - y).abs() > 3) continue;
      if (best == null || (innermost ? p.dx > best.dx : p.dx < best.dx)) {
        best = p;
      }
    }
  }
  return best ?? path.getBounds().center;
}

void paintFrame(Canvas canvas, Size size, FrameSpec s) {
  // Geometry in "frame units", origin at the centre of the glasses.
  final leftRect = Rect.fromLTWH(-(s.gap / 2 + s.lensW), -s.lensH / 2, s.lensW, s.lensH);
  final mirror = Matrix4.diagonal3Values(-1, 1, 1).storage;
  final left = s.lens(leftRect);
  final right = left.transform(mirror);

  // Bridge and temples attach to the real outline (not the bounding box), so
  // round/oval lenses don't leave them floating.
  final by = leftRect.top + leftRect.height * s.bridgeY;
  final ty = leftRect.top + leftRect.height * 0.22;
  final inner = _edgePoint(left, by, innermost: true);
  final outer = _edgePoint(left, ty, innermost: false);

  final bridgeW = s.bridgeW ?? (s.rim > 0 ? s.rim * 0.85 : 7);
  final bridge = Path()
    ..moveTo(inner.dx, inner.dy)
    ..quadraticBezierTo(0, inner.dy - s.bridgeArch * 2, -inner.dx, inner.dy);

  final templeW = s.templeW ?? (s.rim > 0 ? s.rim * 0.9 : 7);
  final templeL = Path()
    ..moveTo(outer.dx, outer.dy)
    ..lineTo(outer.dx - s.templeLen, outer.dy - 14);
  final templeR = templeL.transform(mirror);

  // Brow bar (aviator): runs along the inner part of both lens tops.
  Path? brow;
  if (s.browBar) {
    final yb = leftRect.top + leftRect.height * 0.02;
    final xb = leftRect.left + leftRect.width * 0.60;
    brow = Path()
      ..moveTo(xb, yb)
      ..lineTo(-xb, yb);
  }

  // Fit & centre.
  var bounds = left.getBounds().expandToInclude(right.getBounds());
  bounds = bounds.expandToInclude(templeL.getBounds()).expandToInclude(templeR.getBounds());
  bounds = bounds.inflate(s.rim / 2);
  final scale = [kFitW / bounds.width, kFitH / bounds.height].reduce((a, b) => a < b ? a : b);
  final cx = size.width / 2;
  final cy = size.height / 2 + 6;

  canvas.save();
  canvas.translate(cx, cy);
  canvas.scale(scale);
  canvas.translate(-bounds.center.dx, -bounds.center.dy);

  // Soft ground shadow.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(bounds.center.dx, bounds.bottom + 34),
      width: bounds.width * 0.78,
      height: 30,
    ),
    Paint()
      ..color = const Color(0x1A000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );

  // Lenses: light cool tint + a soft diagonal sheen.
  void paintLens(Path path) {
    final b = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          b.topLeft,
          b.bottomRight,
          const [Color(0x80B0CDEA), Color(0x3AE2EEF9)],
        ),
    );
    canvas.save();
    canvas.clipPath(path);
    final sheen = Path()
      ..moveTo(b.left + b.width * 0.16, b.bottom)
      ..lineTo(b.left + b.width * 0.34, b.bottom)
      ..lineTo(b.left + b.width * 0.64, b.top)
      ..lineTo(b.left + b.width * 0.46, b.top)
      ..close();
    canvas.drawPath(sheen, Paint()..color = const Color(0x40FFFFFF));
    canvas.restore();
  }

  paintLens(left);
  paintLens(right);

  Paint stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c;

  // Temples and bridge go under the rims so the joins look clean.
  canvas.drawPath(templeL, stroke(templeW, s.color));
  canvas.drawPath(templeR, stroke(templeW, s.color));
  canvas.drawPath(bridge, stroke(bridgeW, s.color));
  if (brow != null) canvas.drawPath(brow, stroke(8, s.color));

  if (s.rimless) {
    // Hairline lens edge + mounting screws.
    canvas.drawPath(left, stroke(4.5, const Color(0xAA8A95A5)));
    canvas.drawPath(right, stroke(4.5, const Color(0xAA8A95A5)));
    final dot = Paint()..color = s.color;
    for (final p in [inner, outer]) {
      canvas.drawCircle(p, 8, dot);
      canvas.drawCircle(Offset(-p.dx, p.dy), 8, dot);
    }
  } else {
    canvas.drawPath(left, stroke(s.rim, s.color));
    canvas.drawPath(right, stroke(s.rim, s.color));
    if (s.rim >= 18) {
      // Subtle highlight along the rim to give the acetate some depth.
      final hi = stroke(s.rim * 0.16, const Color(0x2EFFFFFF));
      canvas.drawPath(left, hi);
      canvas.drawPath(right, hi);
    }
  }
  canvas.restore();
}

Future<Uint8List> renderPng(FrameSpec spec, {int width = kW, int height = kH}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(width / kW, height / kH);
  paintFrame(canvas, const Size(1200, 800), spec);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('generate frame illustrations', (tester) async {
    await tester.runAsync(() async {
      final outDir = Directory('assets/images/visagismo/frames')..createSync(recursive: true);
      for (final spec in kSpecs) {
        File('${outDir.path}/${spec.tag}.png').writeAsBytesSync(await renderPng(spec));
      }

      final sheetPath = Platform.environment['FRAME_SHEET_PATH'];
      if (sheetPath != null && sheetPath.isNotEmpty) {
        const cols = 3;
        const cellW = 600, cellH = 400;
        final rows = (kSpecs.length / cols).ceil();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, (cols * cellW).toDouble(), (rows * cellH).toDouble()),
          Paint()..color = Colors.white,
        );
        for (var i = 0; i < kSpecs.length; i++) {
          final col = i % cols;
          final row = i ~/ cols;
          canvas.save();
          canvas.translate((col * cellW).toDouble(), (row * cellH).toDouble());
          canvas.scale(cellW / kW, cellH / kH);
          paintFrame(canvas, const Size(1200, 800), kSpecs[i]);
          canvas.restore();
          final tp = TextPainter(
            text: TextSpan(
              text: kSpecs[i].tag,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset((col * cellW + 12).toDouble(), (row * cellH + 10).toDouble()));
        }
        final image = await recorder.endRecording().toImage(cols * cellW, rows * cellH);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(sheetPath).writeAsBytesSync(data!.buffer.asUint8List());
      }
    });
  });
}
