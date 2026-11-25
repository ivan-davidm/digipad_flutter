import 'dart:math';

import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_lens_detector.dart';

/// Where to draw a frame picture over the captured photo so each lens sits
/// over an eye.
///
/// The frame's lens centres come from the picture itself
/// (`detectFrameLenses`), so any front-view frame with see-through lenses
/// works — no per-frame measurements.

/// A real frame's lens centres are a bit further apart than the wearer's
/// pupils (frame PD = lens width + bridge ≈ 66–70 mm for a ~63 mm adult PD).
const double kLensToEyeDistanceRatio = 1.06;

/// Sanity limits for the frame's total width, in eye distances (an adult face
/// is ≈ 2.2–2.3 eye distances wide). Keeps a bad detection from producing
/// absurd glasses.
const double kMinFrameWidthInEyeDistances = 1.8;
const double kMaxFrameWidthInEyeDistances = 3.0;

/// A frame picture placed on the photo: the picture point ([anchorX],
/// [anchorY]) — the midpoint between its lens centres — goes to
/// ([centerX], [centerY]) in photo pixels; the picture is scaled by [scale]
/// (photo px per picture px) and rotated by [rotation] radians (clockwise).
class GlassesPlacement {
  const GlassesPlacement({
    required this.centerX,
    required this.centerY,
    required this.scale,
    required this.rotation,
    required this.anchorX,
    required this.anchorY,
  });

  final double centerX;
  final double centerY;
  final double scale;
  final double rotation;
  final double anchorX;
  final double anchorY;
}

/// Manual fine-tuning on top of the automatic placement (drag, pinch, twist).
/// Offsets are in photo pixels, so they survive any on-screen scaling and end
/// up identical in the exported image.
class GlassesAdjust {
  const GlassesAdjust({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.rotation = 0,
  });

  static const none = GlassesAdjust();

  final double dx;
  final double dy;
  final double scale;
  final double rotation;

  bool get isNone => dx == 0 && dy == 0 && scale == 1 && rotation == 0;

  GlassesAdjust copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) => GlassesAdjust(
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    scale: (scale ?? this.scale).clamp(0.5, 2.0),
    rotation: (rotation ?? this.rotation).clamp(-pi / 4, pi / 4),
  );

  GlassesPlacement applyTo(GlassesPlacement p) => GlassesPlacement(
    centerX: p.centerX + dx,
    centerY: p.centerY + dy,
    scale: p.scale * scale,
    rotation: p.rotation + rotation,
    anchorX: p.anchorX,
    anchorY: p.anchorY,
  );
}

/// Automatic placement: the frame's lens centres over the eyes found in the
/// photo. Null when [anchor] is missing or does not fall inside a
/// [photoWidth]×[photoHeight] photo (a sign the detector and the decoded
/// photo disagree on orientation — better to fall back to
/// [defaultGlassesPlacement] than to draw the glasses somewhere random).
GlassesPlacement? placeGlasses(
  GlassesAnchor? anchor,
  FrameLensAnchors lenses, {
  required double frameWidth,
  required double photoWidth,
  required double photoHeight,
}) {
  if (anchor == null) return null;
  final inside =
      anchor.eyeCenterX >= 0 &&
      anchor.eyeCenterX <= photoWidth &&
      anchor.eyeCenterY >= 0 &&
      anchor.eyeCenterY <= photoHeight;
  final eyes = anchor.eyeDistance;
  if (!inside || eyes <= 0 || lenses.distance <= 0 || frameWidth <= 0) {
    return null;
  }

  var scale = eyes * kLensToEyeDistanceRatio / lenses.distance;
  // Never narrower / wider than a plausible frame for this face.
  final width = frameWidth * scale;
  final minWidth = eyes * kMinFrameWidthInEyeDistances;
  final maxWidth = eyes * kMaxFrameWidthInEyeDistances;
  if (width < minWidth) scale = minWidth / frameWidth;
  if (width > maxWidth) scale = maxWidth / frameWidth;

  return GlassesPlacement(
    centerX: anchor.eyeCenterX,
    centerY: anchor.eyeCenterY,
    scale: scale,
    // Undo the picture's own tilt, then follow the head.
    rotation: anchor.rollRad - lenses.angle,
    anchorX: lenses.midX,
    anchorY: lenses.midY,
  );
}

/// Where the glasses go when no eyes were found: level, centred, a bit above
/// the middle, about half the photo wide — for the operator to drag into
/// place.
GlassesPlacement defaultGlassesPlacement(
  FrameLensAnchors lenses, {
  required double frameWidth,
  required double photoWidth,
  required double photoHeight,
}) => GlassesPlacement(
  centerX: photoWidth / 2,
  centerY: photoHeight * 0.42,
  scale: frameWidth <= 0 ? 1 : photoWidth * 0.55 / frameWidth,
  rotation: -lenses.angle,
  anchorX: lenses.midX,
  anchorY: lenses.midY,
);
