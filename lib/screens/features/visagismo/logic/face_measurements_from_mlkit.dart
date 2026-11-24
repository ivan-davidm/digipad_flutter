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

/// A face turned left/right (yaw) or looking up/down (pitch) by more than this
/// many degrees is rejected: the 2D proportions are no longer those of the
/// face, so the classification would be meaningless.
const double kMaxHeadYawDeg = 20.0;
const double kMaxHeadPitchDeg = 20.0;

/// Why a photo could not be classified.
enum FaceCaptureIssue {
  /// No usable face found.
  noFace,

  /// Face turned too far left/right (yaw).
  headTurned,

  /// Chin raised or lowered too far (pitch).
  headTilted,

  /// The detector itself failed (for example ML Kit could not start). This is
  /// NOT the same as "no face in the photo": keep them apart so a broken
  /// detector is never reported to the operator as a missing face.
  detectorError,
}

/// Everything learned from one photo: the measurements, the resulting shape
/// (when the photo was usable) and the head pose (for the debug panel).
class FaceAnalysis {
  const FaceAnalysis({
    this.measurements,
    this.shape,
    this.issue,
    this.yawDeg,
    this.pitchDeg,
    this.rollDeg,
    this.errorDetail,
  });

  /// The detector threw: carries the error text for the diagnostics panel.
  factory FaceAnalysis.detectorFailed(Object error) => FaceAnalysis(
    issue: FaceCaptureIssue.detectorError,
    errorDetail: error.toString(),
  );

  final FaceMeasurements? measurements;
  final FaceShapeResult? shape;

  /// Non-null when the photo can't be used and should be retaken.
  final FaceCaptureIssue? issue;

  /// ML Kit head Euler angles, in degrees (null if not reported).
  final double? yawDeg;
  final double? pitchDeg;
  final double? rollDeg;

  /// Only for [FaceCaptureIssue.detectorError].
  final String? errorDetail;

  bool get isUsable => issue == null && shape != null;
}

/// Pure analysis step (no platform calls) so it can be unit-tested with
/// hand-built [Face] objects: picks the main face, rejects bad head poses,
/// measures and classifies.
FaceAnalysis analyzeFaces(List<Face> faces) {
  final face = pickMainFace(faces);
  if (face == null) return const FaceAnalysis(issue: FaceCaptureIssue.noFace);

  final yaw = face.headEulerAngleY;
  final pitch = face.headEulerAngleX;
  final roll = face.headEulerAngleZ;
  final measurements = faceMeasurementsFromFace(face);

  final issue = faceCaptureIssue(face);
  if (issue != null) {
    return FaceAnalysis(
      measurements: measurements,
      issue: issue,
      yawDeg: yaw,
      pitchDeg: pitch,
      rollDeg: roll,
    );
  }
  if (measurements == null) {
    return FaceAnalysis(
      issue: FaceCaptureIssue.noFace,
      yawDeg: yaw,
      pitchDeg: pitch,
      rollDeg: roll,
    );
  }
  return FaceAnalysis(
    measurements: measurements,
    shape: classifyFaceShape(measurements),
    yawDeg: yaw,
    pitchDeg: pitch,
    rollDeg: roll,
  );
}

/// The face to analyse when several are detected: the largest one (the
/// client in front of the camera, not someone in the background).
Face? pickMainFace(List<Face> faces) {
  if (faces.isEmpty) return null;
  double area(Face f) => f.boundingBox.width * f.boundingBox.height;
  return faces.reduce((a, b) => area(a) >= area(b) ? a : b);
}

/// `headTurned` / `headTilted` when the pose makes the 2D proportions
/// unreliable, null when the photo is fine. In-plane roll is NOT an issue —
/// it is corrected in [faceMeasurementsFromFace].
FaceCaptureIssue? faceCaptureIssue(Face face) {
  final yaw = face.headEulerAngleY?.abs();
  if (yaw != null && yaw > kMaxHeadYawDeg) return FaceCaptureIssue.headTurned;
  final pitch = face.headEulerAngleX?.abs();
  if (pitch != null && pitch > kMaxHeadPitchDeg) {
    return FaceCaptureIssue.headTilted;
  }
  return null;
}

/// Contour points as doubles, rotated so that the line through the eyes is
/// horizontal. A head tilted sideways (roll) would otherwise skew every band
/// measurement. Uses the eye landmarks themselves rather than ML Kit's roll
/// angle so it does not depend on that angle's sign convention. Without both
/// eye landmarks (or with an implausible > 45° eye line) the points are
/// returned untouched.
List<Point<double>> _levelledContour(Face face, List<Point<int>> contour) {
  final points = [
    for (final p in contour) Point<double>(p.x.toDouble(), p.y.toDouble()),
  ];
  final a = face.landmarks[FaceLandmarkType.leftEye]?.position;
  final b = face.landmarks[FaceLandmarkType.rightEye]?.position;
  if (a == null || b == null) return points;

  final left = a.x <= b.x ? a : b;
  final right = a.x <= b.x ? b : a;
  final dx = (right.x - left.x).toDouble();
  final dy = (right.y - left.y).toDouble();
  if (dx.abs() < 1) return points;

  final roll = atan2(dy, dx);
  if (roll.abs() < 0.0087 || roll.abs() > pi / 4) return points; // <0.5° or >45°

  final cx = (left.x + right.x) / 2.0;
  final cy = (left.y + right.y) / 2.0;
  final c = cos(roll);
  final s = sin(roll);
  return [
    for (final p in points)
      Point<double>(
        cx + (p.x - cx) * c + (p.y - cy) * s,
        cy - (p.x - cx) * s + (p.y - cy) * c,
      ),
  ];
}

FaceMeasurements? faceMeasurementsFromFace(Face face) {
  final rawContour = face.contours[FaceContourType.face]?.points;
  if (rawContour == null || rawContour.length < 8) return null;
  final contour = _levelledContour(face, rawContour);

  final ys = contour.map((p) => p.y);
  final xs = contour.map((p) => p.x);
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
      if (leftmost == null || p.x < leftmost.x) leftmost = p;
      if (rightmost == null || p.x > rightmost.x) rightmost = p;
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
  final chinPoint = contour.reduce((a, b) => a.y >= b.y ? a : b);

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
