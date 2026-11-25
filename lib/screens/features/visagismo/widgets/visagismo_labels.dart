import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_match.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';

/// Translated names for the visagismo module. Bundled frames are translated
/// by `frameId` (`visagismoFrameName` / `visagismoFrameDetail` in the ARB
/// files); a frame the ARB doesn't know — e.g. one from a future óptica
/// catalog — shows the name it came with.

String frameName(AppLocalizations l10n, FrameCatalogItem item) {
  final name = l10n.visagismoFrameName(item.frameId);
  return name == item.frameId ? item.displayName : name;
}

String? frameDetail(AppLocalizations l10n, FrameCatalogItem item) {
  if (item.detail == null) return null;
  final detail = l10n.visagismoFrameDetail(item.frameId);
  return detail == item.frameId ? item.detail : detail;
}

String faceShapeName(AppLocalizations l10n, FaceShape shape) =>
    l10n.visagismoFaceShapeName(shape.name);

String matchLevelName(AppLocalizations l10n, FrameMatchLevel level) =>
    switch (level) {
      FrameMatchLevel.ideal => l10n.visagismoMatchIdeal,
      FrameMatchLevel.good => l10n.visagismoMatchGood,
      FrameMatchLevel.possible => l10n.visagismoMatchPossible,
      FrameMatchLevel.notRecommended => l10n.visagismoMatchNotRecommended,
    };
