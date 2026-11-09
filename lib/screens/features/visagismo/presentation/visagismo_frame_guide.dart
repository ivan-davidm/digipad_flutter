import 'package:flutter/material.dart';

/// Shared face-guide frame geometry: the capture screen outlines this area
/// to show where to position the face, and the scanning overlay confines its
/// scan effect to the exact same area — so what's highlighted while
/// "scanning" matches what was framed moments earlier, not the whole screen.
///
/// Sized relative to the device's shortest side (not fixed pixels) so the
/// guide stays proportional to the face on screen across phones, tablets and
/// totem displays — a fixed 300x400 box reads correctly on a ~390dp-wide
/// phone but looks tiny on a tablet/totem whose shortest side is much larger.
const double _kReferenceShortestSide = 390;
const double _kReferenceWidth = 300;
const double _kReferenceHeight = 400;
const double _kReferenceBorderRadius = 200;
const double _kMinGuideWidth = 240;
const double _kMaxGuideWidth = 640;

Size faceGuideSize(BuildContext context) {
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  final scale = shortestSide / _kReferenceShortestSide;
  final width = (_kReferenceWidth * scale).clamp(
    _kMinGuideWidth,
    _kMaxGuideWidth,
  );
  final height = width * (_kReferenceHeight / _kReferenceWidth);
  return Size(width, height);
}

double faceGuideBorderRadius(BuildContext context) {
  final width = faceGuideSize(context).width;
  return width * (_kReferenceBorderRadius / _kReferenceWidth);
}
