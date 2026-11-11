import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyFaceShape', () {
    test('alargado: much taller than wide', () {
      const m = FaceMeasurements(
        faceWidthMm: 110,
        faceHeightMm: 165,
        jawWidthMm: 95,
        foreheadWidthMm: 100,
        jawAngleDeg: 140,
        chinSharpness: 0.5,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.alargado);
      expect(result.recommendedFrameTags, contains('oversize'));
    });

    test('redondo: width ~= height, soft jaw, blunt chin', () {
      const m = FaceMeasurements(
        faceWidthMm: 140,
        faceHeightMm: 142,
        jawWidthMm: 125,
        foreheadWidthMm: 130,
        jawAngleDeg: 160,
        chinSharpness: 0.2,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.redondo);
      expect(result.recommendedFrameTags, contains('cat_eye'));
    });

    test('cuadrado: width ~= height, angular jaw close to cheek width', () {
      const m = FaceMeasurements(
        faceWidthMm: 140,
        faceHeightMm: 140,
        jawWidthMm: 135,
        foreheadWidthMm: 130,
        jawAngleDeg: 110,
        chinSharpness: 0.6,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.cuadrado);
      expect(result.recommendedFrameTags, contains('ovalado'));
    });

    test('corazon: wide forehead/cheeks, narrow jaw', () {
      const m = FaceMeasurements(
        faceWidthMm: 140,
        faceHeightMm: 150,
        jawWidthMm: 95,
        foreheadWidthMm: 138,
        jawAngleDeg: 140,
        chinSharpness: 0.7,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.corazon);
      expect(result.recommendedFrameTags, contains('rimless'));
    });

    test('diamante: cheekbones wider than both forehead and jaw', () {
      const m = FaceMeasurements(
        faceWidthMm: 145,
        faceHeightMm: 155,
        jawWidthMm: 110,
        foreheadWidthMm: 105,
        jawAngleDeg: 140,
        chinSharpness: 0.5,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.diamante);
      expect(result.recommendedFrameTags, contains('cat_eye_suave'));
    });

    test('ovalado: balanced ratios, no branch fires decisively', () {
      const m = FaceMeasurements(
        faceWidthMm: 135,
        faceHeightMm: 145,
        jawWidthMm: 128,
        foreheadWidthMm: 128,
        jawAngleDeg: 140,
        chinSharpness: 0.5,
      );
      final result = classifyFaceShape(m);
      expect(result.shape, FaceShape.ovalado);
    });

    test('confidence is always within 0.5..1.0', () {
      const samples = [
        FaceMeasurements(
          faceWidthMm: 110,
          faceHeightMm: 165,
          jawWidthMm: 95,
          foreheadWidthMm: 100,
          jawAngleDeg: 140,
          chinSharpness: 0.5,
        ),
        FaceMeasurements(
          faceWidthMm: 140,
          faceHeightMm: 142,
          jawWidthMm: 125,
          foreheadWidthMm: 130,
          jawAngleDeg: 160,
          chinSharpness: 0.2,
        ),
      ];
      for (final m in samples) {
        final result = classifyFaceShape(m);
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.confidence, lessThanOrEqualTo(1.0));
      }
    });
  });
}
