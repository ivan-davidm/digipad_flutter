import 'dart:io';

import 'package:digipad_flutter/screens/features/visagismo/data/mock_frame_catalog.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// One representative set of measurements per face shape (same ones the
/// classifier tests use), to check that every shape gets real suggestions.
const _samples = <FaceShape, FaceMeasurements>{
  FaceShape.alargado: FaceMeasurements(
    faceWidthMm: 110, faceHeightMm: 165, jawWidthMm: 95,
    foreheadWidthMm: 100, jawAngleDeg: 140, chinSharpness: 0.5,
  ),
  FaceShape.redondo: FaceMeasurements(
    faceWidthMm: 140, faceHeightMm: 142, jawWidthMm: 125,
    foreheadWidthMm: 130, jawAngleDeg: 160, chinSharpness: 0.2,
  ),
  FaceShape.cuadrado: FaceMeasurements(
    faceWidthMm: 140, faceHeightMm: 140, jawWidthMm: 135,
    foreheadWidthMm: 130, jawAngleDeg: 110, chinSharpness: 0.6,
  ),
  FaceShape.corazon: FaceMeasurements(
    faceWidthMm: 140, faceHeightMm: 150, jawWidthMm: 95,
    foreheadWidthMm: 138, jawAngleDeg: 140, chinSharpness: 0.7,
  ),
  FaceShape.diamante: FaceMeasurements(
    faceWidthMm: 145, faceHeightMm: 155, jawWidthMm: 110,
    foreheadWidthMm: 105, jawAngleDeg: 140, chinSharpness: 0.5,
  ),
  FaceShape.ovalado: FaceMeasurements(
    faceWidthMm: 135, faceHeightMm: 145, jawWidthMm: 128,
    foreheadWidthMm: 128, jawAngleDeg: 140, chinSharpness: 0.5,
  ),
};

void main() {
  test('every catalog frame has an illustration on disk', () {
    for (final item in kMockFrameCatalog) {
      expect(
        File(item.thumbnailUrl).existsSync(),
        isTrue,
        reason: '${item.frameId} → ${item.thumbnailUrl}',
      );
    }
  });

  test('each frame shows the illustration of its first shape tag', () {
    for (final item in kMockFrameCatalog) {
      expect(
        item.thumbnailUrl,
        'assets/images/visagismo/frames/${item.shapeTags.first}.png',
        reason: item.frameId,
      );
    }
  });

  test('every face shape gets at least one suggestion, best fit first', () {
    for (final entry in _samples.entries) {
      final result = classifyFaceShape(entry.value);
      expect(result.shape, entry.key, reason: 'sample for ${entry.key.name}');

      final frames =
          rankFramesForTags(kMockFrameCatalog, result.recommendedFrameTags);
      expect(frames, isNotEmpty, reason: entry.key.name);

      // The first suggestion matches the classifier's top-ranked tag that the
      // catalog can actually satisfy.
      final firstTag = result.recommendedFrameTags.firstWhere(
        (t) => kMockFrameCatalog.any((f) => f.shapeTags.contains(t)),
      );
      expect(frames.first.shapeTags, contains(firstTag),
          reason: entry.key.name);
    }
  });
}
