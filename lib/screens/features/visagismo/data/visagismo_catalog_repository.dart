import 'bundled_frame_catalog.dart';

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

  /// Optional second line under the name (material / finish).
  final String? detail;

  const FrameCatalogItem({
    required this.frameId,
    required this.displayName,
    required this.brand,
    required this.tier,
    required this.shapeTags,
    required this.thumbnailUrl,
    this.detail,
  });

  bool get isGeneric => tier == 'generic';
}

/// Source of the frames shown by the visagismo.
///
/// `fetchCatalog()` currently returns [kBundledFrameCatalog] — the real frames
/// bundled with the app (see that file's doc comment) — until each óptica can
/// upload its own catalog (this app has no backend of its own to read one
/// from yet, unlike `digipad`'s Firestore-backed history for this same
/// class). The method signature is final: swapping the body to a real read
/// later doesn't change any call site in the cubit or UI. How each frame
/// matches a face lives in `logic/frame_match.dart`.
class VisagismoCatalogRepository {
  Future<List<FrameCatalogItem>> fetchCatalog() async {
    return kBundledFrameCatalog;
  }

  Future<bool> isFrameUnlockedForCurrentOptica(
    String frameId,
    String tier,
  ) async {
    return tier == 'generic';
  }
}
