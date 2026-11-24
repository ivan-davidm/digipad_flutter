import 'dart:math' as math;
import 'dart:ui';

import 'package:digipad_flutter/screens/features/measurements/optical_logic_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Right lens = the patient's right = the LEFT side of the image.
/// R_TL / R_BR are the outer-top / nasal-bottom corners of that lens;
/// L_TL / L_BR are the nasal-top / outer-bottom corners of the other one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OpticalController> build() async {
    SharedPreferences.setMockInitialValues({});
    final c = OpticalController();
    // Let the async calibration/prefs load finish so it can't overwrite
    // flags we set in a test afterwards.
    await pumpEventQueue();
    c.initialize(
      const {},
      const Size(1000, 800),
      mode: MeasurementMode.sinAccesorio,
    );
    return c;
  }

  Offset pos(OpticalController c, DetectionType t) => c.getPoint(t);

  void select(OpticalController c, DetectionType t) {
    c.selectedPoint = c.points.firstWhere((p) => p.type == t);
  }

  group('mirror right lens -> left lens', () {
    test('outer corner (R_TL) moves the OUTER edge of the left lens (L_BR.x)',
        () async {
      final c = await build();
      final lTLx = pos(c, DetectionType.lensLeftTop).dx;
      final lBRx = pos(c, DetectionType.lensLeftBottom).dx;
      final rTLx = pos(c, DetectionType.lensRightTop).dx;

      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(10, 0);

      expect(pos(c, DetectionType.lensRightTop).dx, rTLx + 10);
      // Outer edge of the left lens moves by the same amount, opposite way.
      expect(pos(c, DetectionType.lensLeftBottom).dx, lBRx - 10);
      // The nasal edge of the left lens must NOT be touched by this corner.
      expect(pos(c, DetectionType.lensLeftTop).dx, lTLx);
    });

    test('nasal corner (R_BR) moves the NASAL edge of the left lens (L_TL.x)',
        () async {
      final c = await build();
      final lTLx = pos(c, DetectionType.lensLeftTop).dx;
      final lBRx = pos(c, DetectionType.lensLeftBottom).dx;

      select(c, DetectionType.lensRightBottom);
      c.nudgeSelectedPoint(-7, 0);

      expect(pos(c, DetectionType.lensLeftTop).dx, lTLx + 7);
      expect(pos(c, DetectionType.lensLeftBottom).dx, lBRx);
    });

    test('heights still pair top<->top and bottom<->bottom', () async {
      final c = await build();

      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(0, 12);
      expect(
        pos(c, DetectionType.lensLeftTop).dy,
        pos(c, DetectionType.lensRightTop).dy,
      );

      select(c, DetectionType.lensRightBottom);
      c.nudgeSelectedPoint(0, -9);
      expect(
        pos(c, DetectionType.lensLeftBottom).dy,
        pos(c, DetectionType.lensRightBottom).dy,
      );
    });

    test('widening the right lens widens the left lens by the same amount',
        () async {
      final c = await build();
      double rightWidth() => (pos(c, DetectionType.lensRightBottom).dx -
              pos(c, DetectionType.lensRightTop).dx)
          .abs();
      double leftWidth() => (pos(c, DetectionType.lensLeftBottom).dx -
              pos(c, DetectionType.lensLeftTop).dx)
          .abs();

      final rBefore = rightWidth();
      final lBefore = leftWidth();

      // Drag the outer edge outwards (towards the image's left border).
      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(-15, 0);

      expect(rightWidth() - rBefore, closeTo(15, 1e-9));
      expect(leftWidth() - lBefore, closeTo(15, 1e-9));
    });

    test('left-lens corners never move the right lens', () async {
      final c = await build();
      final before = {
        for (final t in [
          DetectionType.lensRightTop,
          DetectionType.lensRightBottom,
        ])
          t: pos(c, t),
      };

      select(c, DetectionType.lensLeftTop);
      c.nudgeSelectedPoint(20, 5);
      select(c, DetectionType.lensLeftBottom);
      c.nudgeSelectedPoint(-20, -5);

      for (final e in before.entries) {
        expect(pos(c, e.key), e.value);
      }
    });

    test('linkLenses = false leaves the left lens untouched', () async {
      final c = await build();
      c.linkLenses = false;
      final lTL = pos(c, DetectionType.lensLeftTop);
      final lBR = pos(c, DetectionType.lensLeftBottom);

      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(10, 10);
      select(c, DetectionType.lensRightBottom);
      c.nudgeSelectedPoint(-10, -10);

      expect(pos(c, DetectionType.lensLeftTop), lTL);
      expect(pos(c, DetectionType.lensLeftBottom), lBR);
    });

    test('drag (handleDrag) mirrors the same way as nudge', () async {
      final c = await build();
      final lBRx = pos(c, DetectionType.lensLeftBottom).dx;

      select(c, DetectionType.lensRightTop);
      c.handleDrag(const Offset(30, 0), 2.0); // 30 screen px at 2x = 15 image px

      expect(pos(c, DetectionType.lensLeftBottom).dx, closeTo(lBRx - 15, 1e-9));
    });
  });

  group('with the image auto-rotated on screen', () {
    test('mirrors along the screen axes, not the image axes', () async {
      final c = await build();
      const r = 0.1; // rad
      c.viewRotation = r;
      final eh = Offset(math.cos(r), -math.sin(r)); // screen "right"
      final ev = Offset(math.sin(r), math.cos(r)); // screen "down"
      double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

      final lBR = pos(c, DetectionType.lensLeftBottom);

      // A purely screen-horizontal drag of 10 px, expressed in image space.
      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(eh.dx * 10, eh.dy * 10);

      // The mirrored outer corner moves 10 px the opposite way on screen...
      final moved = pos(c, DetectionType.lensLeftBottom) - lBR;
      expect(dot(moved, eh), closeTo(-10, 1e-9));
      // ...and does not drift vertically on screen.
      expect(dot(moved, ev), closeTo(0, 1e-9));
    });

    test('mirrored top edge ends at the same on-screen height', () async {
      final c = await build();
      const r = -0.07;
      c.viewRotation = r;
      final ev = Offset(math.sin(r), math.cos(r));
      double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

      select(c, DetectionType.lensRightTop);
      c.nudgeSelectedPoint(3, 11);

      expect(
        dot(pos(c, DetectionType.lensLeftTop), ev),
        closeTo(dot(pos(c, DetectionType.lensRightTop), ev), 1e-9),
      );
    });
  });
}
