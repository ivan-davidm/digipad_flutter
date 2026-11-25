import 'dart:math';
import 'dart:typed_data';

/// Where the two lenses are in a front-view frame picture, in that picture's
/// pixels. Used to put each lens over an eye (see `glasses_fit.dart`).
class FrameLensAnchors {
  const FrameLensAnchors({
    required this.leftX,
    required this.leftY,
    required this.rightX,
    required this.rightY,
    this.detected = true,
  });

  /// Centre of the lens on the picture's left (viewer's left).
  final double leftX;
  final double leftY;

  /// Centre of the lens on the picture's right.
  final double rightX;
  final double rightY;

  /// False when the lenses could not be found and these are a guess.
  final bool detected;

  double get midX => (leftX + rightX) / 2;
  double get midY => (leftY + rightY) / 2;
  double get distance => sqrt(pow(rightX - leftX, 2) + pow(rightY - leftY, 2));

  /// Tilt of the lens line in the picture (0 for a level frame).
  double get angle => atan2(rightY - leftY, rightX - leftX);

  /// Lens centres at 27 % / 73 % of the width, mid height: a sensible guess
  /// for a centred front view when detection fails.
  factory FrameLensAnchors.guess(int width, int height) => FrameLensAnchors(
    leftX: width * 0.27,
    leftY: height / 2,
    rightX: width * 0.73,
    rightY: height / 2,
    detected: false,
  );
}

/// Finds the lenses of a frame picture with a transparent background and
/// see-through lenses: each lens is a transparent hole fully enclosed by the
/// frame. [rgba] holds straight (non-premultiplied) RGBA bytes.
///
/// 1. Every pixel with some opacity is "frame"; the frame is grown by one
///    pixel so the gaps in thin, anti-aliased metal wire cannot leak.
/// 2. Transparent pixels reachable from the picture's border are "outside".
/// 3. The transparent pixels left are holes. The biggest one on each half of
///    the picture is a lens (bridge gaps and nose-pad gaps are much smaller).
///
/// Returns null when there aren't two plausible lens holes.
FrameLensAnchors? detectFrameLenses(Uint8List rgba, int width, int height) {
  final n = width * height;
  if (rgba.length < n * 4 || width < 8 || height < 8) return null;

  final solid = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] > 8) solid[i] = 1;
  }
  // Grow the frame by one pixel (4-neighbourhood).
  final grown = Uint8List.fromList(solid);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      if (solid[i] == 1) continue;
      if ((x > 0 && solid[i - 1] == 1) ||
          (x < width - 1 && solid[i + 1] == 1) ||
          (y > 0 && solid[i - width] == 1) ||
          (y < height - 1 && solid[i + width] == 1)) {
        grown[i] = 1;
      }
    }
  }

  // 0 = unvisited, 1 = outside, 2+ = hole id.
  final label = Int32List(n);
  final stack = <int>[];
  void flood(int seed, int id, void Function(int i)? visit) {
    stack
      ..clear()
      ..add(seed);
    label[seed] = id;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      visit?.call(i);
      final x = i % width;
      final y = i ~/ width;
      void push(int j) {
        if (label[j] == 0 && grown[j] == 0) {
          label[j] = id;
          stack.add(j);
        }
      }

      if (x > 0) push(i - 1);
      if (x < width - 1) push(i + 1);
      if (y > 0) push(i - width);
      if (y < height - 1) push(i + width);
    }
  }

  for (var x = 0; x < width; x++) {
    for (final y in [0, height - 1]) {
      final i = y * width + x;
      if (label[i] == 0 && grown[i] == 0) flood(i, 1, null);
    }
  }
  for (var y = 0; y < height; y++) {
    for (final x in [0, width - 1]) {
      final i = y * width + x;
      if (label[i] == 0 && grown[i] == 0) flood(i, 1, null);
    }
  }

  final holes = <_Hole>[];
  var nextId = 2;
  for (var i = 0; i < n; i++) {
    if (label[i] != 0 || grown[i] != 0) continue;
    final hole = _Hole();
    flood(i, nextId++, (j) => hole.add(j % width, j ~/ width));
    holes.add(hole);
  }

  // A lens covers a decent share of the picture; ignore small gaps.
  final minArea = n * 0.04;
  _Hole? best(bool leftHalf) {
    _Hole? pick;
    for (final h in holes) {
      if (h.area < minArea) continue;
      if ((h.cx < width / 2) != leftHalf) continue;
      if (pick == null || h.area > pick.area) pick = h;
    }
    return pick;
  }

  final left = best(true);
  final right = best(false);
  if (left == null || right == null) return null;
  // Two lenses of one pair are about the same size.
  final ratio = left.area / right.area;
  if (ratio < 0.6 || ratio > 1.67) return null;

  return FrameLensAnchors(
    leftX: left.cx,
    leftY: left.cy,
    rightX: right.cx,
    rightY: right.cy,
  );
}

class _Hole {
  int area = 0;
  double _sx = 0;
  double _sy = 0;

  void add(int x, int y) {
    area++;
    _sx += x;
    _sy += y;
  }

  // +0.5: centre of the pixel, not its corner.
  double get cx => _sx / area + 0.5;
  double get cy => _sy / area + 0.5;
}
