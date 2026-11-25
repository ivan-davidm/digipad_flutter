import 'dart:io';
import 'dart:ui' as ui;

import 'package:digipad_flutter/screens/features/visagismo/data/bundled_frame_catalog.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_lens_detector.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_match.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/visagismo_labels.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
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
  test('every catalog frame has its picture on disk', () {
    for (final item in kBundledFrameCatalog) {
      expect(
        File(item.thumbnailUrl).existsSync(),
        isTrue,
        reason: '${item.frameId} → ${item.thumbnailUrl}',
      );
    }
  });

  test('frame ids are unique', () {
    final ids = kBundledFrameCatalog.map((f) => f.frameId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every tag is one the classifier knows (no typos)', () {
    final known = <String>{};
    for (final m in _samples.values) {
      final r = classifyFaceShape(m);
      known
        ..addAll(r.recommendedFrameTags)
        ..addAll(r.avoidFrameTags);
    }
    for (final item in kBundledFrameCatalog) {
      for (final tag in item.shapeTags) {
        expect(known, contains(tag), reason: '${item.frameId}: $tag');
      }
    }
  });

  test('every face shape gets at least one ideal frame, shown first', () {
    for (final entry in _samples.entries) {
      final result = classifyFaceShape(entry.value);
      expect(result.shape, entry.key, reason: 'sample for ${entry.key.name}');

      final ranked = rankFramesByMatch(kBundledFrameCatalog, result);
      expect(ranked.length, kBundledFrameCatalog.length, reason: 'all shown');
      expect(ranked.first.level, FrameMatchLevel.ideal, reason: entry.key.name);
      // Levels never go back up along the list.
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i].level!.index,
          greaterThanOrEqualTo(ranked[i - 1].level!.index),
        );
      }
    }
  });

  test('the lenses of every bundled frame are found and level', () async {
    for (final item in kBundledFrameCatalog) {
      final codec = await ui.instantiateImageCodec(
        File(item.thumbnailUrl).readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
      final lenses = detectFrameLenses(rgba, image.width, image.height);
      expect(lenses, isNotNull, reason: item.frameId);
      // One lens per half, about half the picture apart, on one line.
      expect(lenses!.leftX, lessThan(image.width / 2), reason: item.frameId);
      expect(lenses.rightX, greaterThan(image.width / 2), reason: item.frameId);
      expect(
        lenses.distance / image.width,
        inInclusiveRange(0.4, 0.6),
        reason: item.frameId,
      );
      expect(lenses.angle.abs(), lessThan(0.02), reason: item.frameId);
    }
  });

  test('every frame and face shape is translated in es / en / pt', () {
    for (final code in ['es', 'en', 'pt']) {
      final l10n = lookupAppLocalizations(Locale(code));
      for (final item in kBundledFrameCatalog) {
        expect(
          l10n.visagismoFrameName(item.frameId),
          isNot(item.frameId),
          reason: '$code: name of ${item.frameId}',
        );
        if (item.detail != null) {
          expect(
            l10n.visagismoFrameDetail(item.frameId),
            isNot(item.frameId),
            reason: '$code: detail of ${item.frameId}',
          );
        }
      }
      for (final shape in FaceShape.values) {
        expect(
          faceShapeName(l10n, shape),
          isNot(shape.name),
          reason: '$code: ${shape.name}',
        );
      }
    }
    // Spanish names match the catalog's own names.
    final es = lookupAppLocalizations(const Locale('es'));
    for (final item in kBundledFrameCatalog) {
      expect(frameName(es, item), item.displayName);
    }
  });
}
