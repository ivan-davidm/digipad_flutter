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
  ) {
    return catalog
        .where((item) => item.shapeTags.any(shapeTags.contains))
        .toList();
  }

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
