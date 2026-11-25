import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';

/// How well a frame suits the classified face, best first. The result screen
/// shows EVERY frame (the client decides what they like), sorted by this and
/// colour-coded so the ideal ones stand out (client request 2026-11-25).
enum FrameMatchLevel {
  /// Has the classifier's top recommendation for this face. Green.
  ideal,

  /// Has another of the recommended styles. Yellow.
  good,

  /// Neither recommended nor discouraged. Orange.
  possible,

  /// Has a style the classifier says to avoid for this face. Red.
  notRecommended,
}

class RankedFrame {
  const RankedFrame(this.item, this.level);

  final FrameCatalogItem item;

  /// Null when there is no classification (no face found): no colours.
  final FrameMatchLevel? level;
}

/// Match level of [item] for [shape]. "Avoid" wins over "recommended": a
/// frame that is both is shown as not recommended.
FrameMatchLevel frameMatchLevel(FrameCatalogItem item, FaceShapeResult shape) {
  if (item.shapeTags.any(shape.avoidFrameTags.contains)) {
    return FrameMatchLevel.notRecommended;
  }
  final recommended = shape.recommendedFrameTags;
  if (recommended.isNotEmpty && item.shapeTags.contains(recommended.first)) {
    return FrameMatchLevel.ideal;
  }
  if (item.shapeTags.any(recommended.contains)) return FrameMatchLevel.good;
  return FrameMatchLevel.possible;
}

/// Every frame in [catalog], best match first. Within a level, frames whose
/// best tag ranks higher in the recommendation come first; ties keep the
/// catalog order. With no [shape], the catalog order and no levels.
List<RankedFrame> rankFramesByMatch(
  List<FrameCatalogItem> catalog,
  FaceShapeResult? shape,
) {
  if (shape == null) {
    return [for (final item in catalog) RankedFrame(item, null)];
  }
  final recommended = shape.recommendedFrameTags;
  int tagRank(FrameCatalogItem item) {
    var best = recommended.length;
    for (final tag in item.shapeTags) {
      final i = recommended.indexOf(tag);
      if (i >= 0 && i < best) best = i;
    }
    return best;
  }

  final scored = [
    for (var i = 0; i < catalog.length; i++)
      (
        frameMatchLevel(catalog[i], shape).index,
        tagRank(catalog[i]),
        i,
        catalog[i],
      ),
  ];
  scored.sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$3.compareTo(b.$3);
  });
  return [
    for (final s in scored)
      RankedFrame(s.$4, FrameMatchLevel.values[s.$1]),
  ];
}
