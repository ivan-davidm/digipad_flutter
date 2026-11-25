import 'dart:math';
import 'dart:typed_data';

import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_lens_detector.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/glasses_fit.dart';
import 'package:flutter_test/flutter_test.dart';

GlassesAnchor anchor({
  double x = 500,
  double y = 450,
  double eyes = 120,
  double roll = 0,
}) => GlassesAnchor(
  eyeCenterX: x,
  eyeCenterY: y,
  eyeDistance: eyes,
  faceWidthAtEyes: 290,
  rollRad: roll,
);

/// Lens centres 100 px apart in a 200 px wide picture.
const lenses = FrameLensAnchors(leftX: 50, leftY: 40, rightX: 150, rightY: 40);

/// Synthetic RGBA picture: two square rings ("lenses") joined by a bar, on a
/// transparent background; [gap] opens a hole in the left ring's wire.
Uint8List ringsPicture(int w, int h, {bool gap = false}) {
  final px = Uint8List(w * h * 4);
  void set(int x, int y) => px[(y * w + x) * 4 + 3] = 255;
  void ring(int x0, int y0, int x1, int y1) {
    for (var x = x0; x <= x1; x++) {
      set(x, y0);
      set(x, y1);
    }
    for (var y = y0; y <= y1; y++) {
      set(x0, y);
      set(x1, y);
    }
  }

  ring(10, 10, 90, 70); // left lens, centre (50.5, 40.5)
  ring(110, 10, 190, 70); // right lens, centre (150.5, 40.5)
  for (var x = 90; x <= 110; x++) {
    set(x, 30);
  }
  if (gap) px[(40 * w + 10) * 4 + 3] = 0; // 1 px hole in the left ring
  return px;
}

void main() {
  group('detectFrameLenses', () {
    test('finds the centre of each enclosed lens', () {
      final a = detectFrameLenses(ringsPicture(200, 80), 200, 80)!;
      expect(a.leftX, closeTo(50.5, 0.6));
      expect(a.leftY, closeTo(40.5, 0.6));
      expect(a.rightX, closeTo(150.5, 0.6));
      expect(a.distance, closeTo(100, 1));
      expect(a.angle, closeTo(0, 0.01));
    });

    test('a 1 px gap in a thin wire does not open the lens', () {
      expect(
        detectFrameLenses(ringsPicture(200, 80, gap: true), 200, 80),
        isNotNull,
      );
    });

    test('nothing enclosed → null (caller falls back to a guess)', () {
      expect(detectFrameLenses(Uint8List(200 * 80 * 4), 200, 80), isNull);
      final guess = FrameLensAnchors.guess(200, 80);
      expect(guess.detected, isFalse);
      expect(guess.midX, 100);
    });
  });

  group('placeGlasses', () {
    test('lens centres go over the eyes, a bit wider apart, rotated', () {
      final p = placeGlasses(
        anchor(roll: 0.1),
        lenses,
        frameWidth: 200,
        photoWidth: 1000,
        photoHeight: 1200,
      )!;
      expect(p.centerX, 500);
      expect(p.centerY, 450);
      expect(p.anchorX, 100); // midpoint of the lenses in the picture
      expect(p.anchorY, 40);
      // 100 px between lenses → 120 px eyes × 1.06
      expect(
        p.scale * lenses.distance,
        closeTo(120 * kLensToEyeDistanceRatio, 1e-9),
      );
      expect(p.rotation, closeTo(0.1, 1e-9));
    });

    test('an implausible frame width is clamped to the eye distance', () {
      // Lenses almost touching: would make a huge frame.
      const close = FrameLensAnchors(
        leftX: 95,
        leftY: 40,
        rightX: 105,
        rightY: 40,
      );
      final p = placeGlasses(
        anchor(),
        close,
        frameWidth: 200,
        photoWidth: 1000,
        photoHeight: 1200,
      )!;
      expect(p.scale * 200, closeTo(120 * kMaxFrameWidthInEyeDistances, 1e-9));
    });

    test('no anchor, or eyes outside the photo → no automatic placement', () {
      expect(
        placeGlasses(
          null,
          lenses,
          frameWidth: 200,
          photoWidth: 1000,
          photoHeight: 1200,
        ),
        isNull,
      );
      expect(
        placeGlasses(
          anchor(x: 1500),
          lenses,
          frameWidth: 200,
          photoWidth: 1000,
          photoHeight: 1200,
        ),
        isNull,
      );
    });

    test('manual adjust moves, scales and rotates, within limits', () {
      final base = defaultGlassesPlacement(
        lenses,
        frameWidth: 200,
        photoWidth: 1000,
        photoHeight: 1200,
      );
      final p = const GlassesAdjust(
        dx: 10,
        dy: -5,
        scale: 1.2,
        rotation: 0.1,
      ).applyTo(base);
      expect(p.centerX, base.centerX + 10);
      expect(p.centerY, base.centerY - 5);
      expect(p.scale, closeTo(base.scale * 1.2, 1e-9));
      expect(p.rotation, closeTo(0.1, 1e-9));
      expect(p.anchorX, base.anchorX);

      final clamped = GlassesAdjust.none.copyWith(scale: 9, rotation: 3);
      expect(clamped.scale, 2.0);
      expect(clamped.rotation, pi / 4);
    });
  });
}
