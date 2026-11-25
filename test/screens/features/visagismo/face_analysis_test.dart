import 'dart:math';
import 'dart:ui' show Rect;

import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Synthetic face: an ellipse contour (36 points, like ML Kit's) rotated by
/// [rollRad] around its centre, plus eye landmarks rotated the same way.
Face fakeFace({
  double cx = 500,
  double cy = 500,
  double rx = 150,
  double ry = 200,
  double rollRad = 0,
  bool withEyes = true,
  double? yaw,
  double? pitch,
}) {
  Point<int> rotate(double x, double y) {
    final dx = x - cx;
    final dy = y - cy;
    return Point<int>(
      (cx + dx * cos(rollRad) - dy * sin(rollRad)).round(),
      (cy + dx * sin(rollRad) + dy * cos(rollRad)).round(),
    );
  }

  final contour = [
    for (var i = 0; i < 36; i++)
      rotate(
        cx + rx * cos(2 * pi * i / 36),
        cy + ry * sin(2 * pi * i / 36),
      ),
  ];
  final eyeDx = rx * 0.4;
  final eyeY = cy - ry * 0.25;
  return Face(
    boundingBox: Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    ),
    landmarks: {
      if (withEyes) ...{
        FaceLandmarkType.leftEye: FaceLandmark(
          type: FaceLandmarkType.leftEye,
          position: rotate(cx + eyeDx, eyeY), // subject's left = image right
        ),
        FaceLandmarkType.rightEye: FaceLandmark(
          type: FaceLandmarkType.rightEye,
          position: rotate(cx - eyeDx, eyeY),
        ),
      },
    },
    contours: {
      FaceContourType.face: FaceContour(
        type: FaceContourType.face,
        points: contour,
      ),
    },
    headEulerAngleX: pitch,
    headEulerAngleY: yaw,
    headEulerAngleZ: rollRad * 180 / pi,
  );
}

double wh(FaceAnalysis a) =>
    a.measurements!.faceWidthMm / a.measurements!.faceHeightMm;

void main() {
  group('analyzeFaces', () {
    test('no faces → noFace', () {
      final a = analyzeFaces(const []);
      expect(a.issue, FaceCaptureIssue.noFace);
      expect(a.isUsable, isFalse);
    });

    test('a straight face is usable and measured', () {
      final a = analyzeFaces([fakeFace()]);
      expect(a.isUsable, isTrue);
      expect(a.issue, isNull);
      expect(wh(a), closeTo(0.75, 0.01));
    });

    test('a sideways-tilted head is levelled using the eye line', () {
      const roll = 30 * pi / 180;
      final levelled = analyzeFaces([fakeFace(rollRad: roll)]);
      expect(wh(levelled), closeTo(0.75, 0.02));

      // Without eye landmarks nothing can be corrected, so the tilt skews
      // the proportions (this is what used to happen to every tilted photo).
      final skewed = analyzeFaces([fakeFace(rollRad: roll, withEyes: false)]);
      expect(wh(skewed), greaterThan(0.82));
    });

    test('tilt in the opposite direction is levelled too (sign-independent)',
        () {
      final a = analyzeFaces([fakeFace(rollRad: -25 * pi / 180)]);
      expect(wh(a), closeTo(0.75, 0.02));
    });

    test('picks the largest face when several are detected', () {
      final background = fakeFace(cx: 200, cy: 200, rx: 50, ry: 70);
      final client = fakeFace();
      for (final faces in [
        [background, client],
        [client, background],
      ]) {
        final a = analyzeFaces(faces);
        expect(a.measurements!.faceWidthMm, closeTo(300, 3));
      }
    });
  });

  group('detector failures', () {
    test('are reported as such, never as "no face"', () {
      final a = FaceAnalysis.detectorFailed(StateError('mlkit not initialised'));
      expect(a.issue, FaceCaptureIssue.detectorError);
      expect(a.issue, isNot(FaceCaptureIssue.noFace));
      expect(a.errorDetail, contains('mlkit not initialised'));
      expect(a.isUsable, isFalse);
      expect(a.shape, isNull);
    });
  });

  group('head pose gate', () {
    test('turned too far (yaw) → headTurned, no shape', () {
      final a = analyzeFaces([fakeFace(yaw: 30)]);
      expect(a.issue, FaceCaptureIssue.headTurned);
      expect(a.shape, isNull);
      expect(a.yawDeg, 30);
    });

    test('works for negative yaw too', () {
      expect(
        analyzeFaces([fakeFace(yaw: -25)]).issue,
        FaceCaptureIssue.headTurned,
      );
    });

    test('chin too high/low (pitch) → headTilted', () {
      expect(
        analyzeFaces([fakeFace(pitch: -24)]).issue,
        FaceCaptureIssue.headTilted,
      );
      expect(
        analyzeFaces([fakeFace(pitch: 22)]).issue,
        FaceCaptureIssue.headTilted,
      );
    });

    test('small angles and unreported angles are accepted', () {
      expect(analyzeFaces([fakeFace(yaw: 12, pitch: 8)]).isUsable, isTrue);
      expect(analyzeFaces([fakeFace()]).isUsable, isTrue);
      expect(
        analyzeFaces([fakeFace(yaw: kMaxHeadYawDeg)]).isUsable,
        isTrue,
        reason: 'the limit itself is allowed',
      );
    });

    test('the rejected photo still reports its measurements for diagnostics',
        () {
      final a = analyzeFaces([fakeFace(yaw: 40)]);
      expect(a.measurements, isNotNull);
    });
  });

  group('frame match levels', () {
    FrameCatalogItem frame(String id, List<String> tags) => FrameCatalogItem(
      frameId: id,
      displayName: id,
      brand: 'Genérico',
      tier: 'generic',
      shapeTags: tags,
      thumbnailUrl: 'x',
    );

    const shape = FaceShapeResult(
      shape: FaceShape.redondo,
      recommendedFrameTags: ['cuadrado', 'rectangular', 'cat_eye'],
      avoidFrameTags: ['redondo_chico'],
      confidence: 1,
    );

    final catalog = [
      frame('a_round_small', ['ovalado', 'redondo_chico']),
      frame('b_cat', ['cat_eye']),
      frame('c_square', ['cuadrado']),
      frame('d_other', ['rimless']),
      frame('e_rect', ['rectangular']),
      frame('f_square2', ['cuadrado', 'oversize']),
      frame('g_square_avoided', ['cuadrado', 'redondo_chico']),
    ];

    test('top recommendation = ideal, other recommended = good, '
        'neither = possible, avoided = not recommended', () {
      FrameMatchLevel level(String id) =>
          frameMatchLevel(catalog.firstWhere((f) => f.frameId == id), shape);
      expect(level('c_square'), FrameMatchLevel.ideal);
      expect(level('e_rect'), FrameMatchLevel.good);
      expect(level('b_cat'), FrameMatchLevel.good);
      expect(level('d_other'), FrameMatchLevel.possible);
      expect(level('a_round_small'), FrameMatchLevel.notRecommended);
      // "avoid" wins even over the top recommendation
      expect(level('g_square_avoided'), FrameMatchLevel.notRecommended);
    });

    test('every frame is kept, best first; ties keep the catalog order', () {
      final ranked = rankFramesByMatch(catalog, shape);
      expect(ranked.map((r) => r.item.frameId), [
        'c_square', 'f_square2', // ideal
        'e_rect', 'b_cat', // good: rectangular (rank 1) before cat_eye (2)
        'd_other', // possible
        // not recommended: the one that also has the top style first
        'g_square_avoided', 'a_round_small',
      ]);
    });

    test('no classification → catalog order, no levels', () {
      final ranked = rankFramesByMatch(catalog, null);
      expect(ranked.map((r) => r.item.frameId), catalog.map((f) => f.frameId));
      expect(ranked.every((r) => r.level == null), isTrue);
    });
  });

  group('glassesAnchorFromFace', () {
    // fakeFace: eyes 120 px apart, 50 px above the centre; the ellipse is
    // ≈ 295 px wide around that line.
    test('level face: eye midpoint, eye distance and face width', () {
      final a = glassesAnchorFromFace(fakeFace())!;
      expect(a.eyeCenterX, closeTo(500, 1));
      expect(a.eyeCenterY, closeTo(450, 1));
      expect(a.eyeDistance, closeTo(120, 1));
      expect(a.rollRad, closeTo(0, 0.01));
      expect(a.faceWidthAtEyes, closeTo(295, 8));
    });

    test('tilted face: roll follows the eye line, width is measured level', () {
      final a = glassesAnchorFromFace(fakeFace(rollRad: 0.2))!;
      expect(a.rollRad, closeTo(0.2, 0.02));
      expect(a.eyeDistance, closeTo(120, 2));
      expect(a.faceWidthAtEyes, closeTo(295, 10));
    });

    test('no eyes → no anchor', () {
      expect(glassesAnchorFromFace(fakeFace(withEyes: false)), isNull);
    });

    test('analyzeFaces carries the anchor, even for a rejected pose', () {
      expect(analyzeFaces([fakeFace()]).glasses, isNotNull);
      expect(analyzeFaces([fakeFace(yaw: 40)]).glasses, isNotNull);
    });
  });
}
