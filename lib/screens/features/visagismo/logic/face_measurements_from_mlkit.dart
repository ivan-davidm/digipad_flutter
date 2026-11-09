import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_shape_classifier.dart';

/// Derives the same scalar ratios [classifyFaceShape] expects, but from an
/// ML Kit 2D face contour instead of an ARCore 3D face mesh (see the
/// visagismo module's history for why: live ARCore Augmented Faces rendering
/// via SceneView hit an unresolved native `AR_ERROR_TEXTURE_NOT_SET` bug on
/// real hardware, so the live-AR-overlay approach was replaced with
/// "capture a photo, measure it, show reference photos" instead).
///
/// [classifyFaceShape] is purely ratio-based (width/height, jaw/cheek,
/// forehead/cheek, plus an angle), so it works identically whether the
/// inputs are millimeters from a 3D mesh or pixels from a 2D photo — only
/// this extraction step changes, not the classifier itself.
///
/// Deliberately index-free: rather than hardcoding which of the face
/// contour's ~36 points are "the jaw corners" (fragile, device/ML-Kit-version
/// dependent), this scans the contour for the width at each face-height band
/// (top/bottom thirds) — robust to exactly how ML Kit orders those points.
FaceMeasurements? faceMeasurementsFromFace(Face face) {
  final contour = face.contours[FaceContourType.face]?.points;
  if (contour == null || contour.length < 8) return null;

  final ys = contour.map((p) => p.y.toDouble());
  final xs = contour.map((p) => p.x.toDouble());
  final minY = ys.reduce(min);
  final maxY = ys.reduce(max);
  final faceHeight = maxY - minY;
  if (faceHeight <= 0) return null;
  final faceWidth = xs.reduce(max) - xs.reduce(min);
  if (faceWidth <= 0) return null;

  // Returns (leftmost, rightmost) points whose y falls within the given
  // band of the face's height (0 = top of contour, 1 = bottom/chin).
  (Point<double>, Point<double>)? widestPairInBand(
    double bandStart,
    double bandEnd,
  ) {
    Point<double>? leftmost;
    Point<double>? rightmost;
    for (final p in contour) {
      final t = (p.y - minY) / faceHeight;
      if (t < bandStart || t > bandEnd) continue;
      final point = Point(p.x.toDouble(), p.y.toDouble());
      if (leftmost == null || point.x < leftmost.x) leftmost = point;
      if (rightmost == null || point.x > rightmost.x) rightmost = point;
    }
    if (leftmost == null || rightmost == null) return null;
    return (leftmost, rightmost);
  }

  final foreheadPair = widestPairInBand(0.0, 0.25);
  // Measured higher up the jaw (was 0.65-0.9) to stay clear of the band
  // right above the chin, where a beard most distorts ML Kit's contour by
  // filling in what would otherwise be a soft jaw curve — which previously
  // biased round/chubby faces toward a sharper, more "square" angle reading.
  final jawPair = widestPairInBand(0.55, 0.78);
  if (foreheadPair == null || jawPair == null) return null;

  final foreheadWidth = foreheadPair.$2.x - foreheadPair.$1.x;
  final jawWidth = jawPair.$2.x - jawPair.$1.x;

  // Chin tip: the contour point with the largest y (bottommost).
  final chin = contour.reduce((a, b) => a.y >= b.y ? a : b);
  final chinPoint = Point(chin.x.toDouble(), chin.y.toDouble());

  // Same angle-at-the-chin proxy the native mesh version used, just in 2D
  // (z implicitly 0 for both vectors, which doesn't change the angle between
  // them since they're both already planar here).
  final v1 = jawPair.$1 - chinPoint;
  final v2 = jawPair.$2 - chinPoint;
  final mag1 = v1.magnitude;
  final mag2 = v2.magnitude;
  final jawAngleDeg = (mag1 == 0 || mag2 == 0)
      ? 150.0
      : _radToDeg(
          acos(((v1.x * v2.x + v1.y * v2.y) / (mag1 * mag2)).clamp(-1.0, 1.0)),
        );
  final chinSharpness = ((160.0 - jawAngleDeg) / 100.0).clamp(0.0, 1.0);

  return FaceMeasurements(
    faceWidthMm: faceWidth,
    faceHeightMm: faceHeight,
    jawWidthMm: jawWidth,
    foreheadWidthMm: foreheadWidth,
    jawAngleDeg: jawAngleDeg,
    chinSharpness: chinSharpness,
  );
}

double _radToDeg(double rad) => rad * 180.0 / pi;
