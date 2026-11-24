import 'mock_frame_catalog.dart';

class FrameCatalogItem {
  final String frameId;
  final String displayName;
  final String brand;
  final String tier; // "generic" | "premium"
  final List<String> shapeTags;

  /// Either a bundled asset path (`assets/images/...`) or a network URL
  /// (`http...`) — `FrameSuggestionsList` picks `Image.asset`/`Image.network`
  /// based on which. Mock data always uses an asset path.
  final String thumbnailUrl;

  const FrameCatalogItem({
    required this.frameId,
    required this.displayName,
    required this.brand,
    required this.tier,
    required this.shapeTags,
    required this.thumbnailUrl,
  });

  bool get isGeneric => tier == 'generic';
}

/// Resolves which frames to suggest for a classified face shape.
///
/// `fetchCatalog()` currently returns [kMockFrameCatalog] — a hardcoded
/// placeholder list (see that file's doc comment), standing in until each
/// óptica can upload its own real catalog. The method signature is final:
/// swapping the body to a real Firestore/local-catalog read later doesn't
/// change any call site in the cubit or UI, which already treat the catalog
/// as "whatever list comes back."
class VisagismoCatalogRepository {
  Future<List<FrameCatalogItem>> fetchCatalog() async {
    return kMockFrameCatalog;
  }

  List<FrameCatalogItem> filterByShapeTags(
    List<FrameCatalogItem> catalog,
    List<String> shapeTags,
  ) => rankFramesForTags(catalog, shapeTags);

  /// Entitlement resolution is a deliberate stub for this phase: there is no
  /// purchasing/entitlement UI yet, so every account sees only the generic
  /// tier. Kept as a method (rather than inlined into `isGeneric` checks) so
  /// wiring the real `opticas/{opticaId}/entitlements` read later only
  /// changes this method's body.
  Future<bool> isFrameUnlockedForCurrentOptica(
    String frameId,
    String tier,
  ) async {
    if (tier == 'generic') return true;
    return false;
  }
}

/// Frames that match any of [recommendedTags], best fit first.
///
/// `recommendedTags` comes ranked from the classifier (best-fit tag first), so
/// each frame is scored by the position of its best-matching tag and the list
/// is ordered by that score. Ties keep the catalog's own order. Frames with no
/// matching tag are dropped.
List<FrameCatalogItem> rankFramesForTags(
  List<FrameCatalogItem> catalog,
  List<String> recommendedTags,
) {
  int rankOf(FrameCatalogItem item) {
    var best = -1;
    for (final tag in item.shapeTags) {
      final i = recommendedTags.indexOf(tag);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  final scored = <(int, int, FrameCatalogItem)>[];
  for (var i = 0; i < catalog.length; i++) {
    final rank = rankOf(catalog[i]);
    if (rank >= 0) scored.add((rank, i, catalog[i]));
  }
  scored.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored) s.$3];
}
