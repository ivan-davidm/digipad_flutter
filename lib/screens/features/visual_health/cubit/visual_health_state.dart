enum VisualHealthCategory {
  visionTests,
  ishihara,
  childrenBicromatic,
  ametropia,
  pathologies,
  amsler,
}

class VisualHealthState {
  final VisualHealthCategory selectedCategory;
  final Map<VisualHealthCategory, List<String>> categoryImages;
  final int currentTestIndex;
  final bool isInitialized;

  VisualHealthState({
    this.selectedCategory = VisualHealthCategory.visionTests,
    this.categoryImages = const {},
    this.currentTestIndex = 0,
    this.isInitialized = false,
  });

  List<String> get testImages =>
      categoryImages[selectedCategory] ?? const [];

  String? get currentTestImage {
    final images = testImages;
    if (images.isEmpty || currentTestIndex >= images.length) return null;
    return images[currentTestIndex];
  }

  VisualHealthState copyWith({
    VisualHealthCategory? selectedCategory,
    Map<VisualHealthCategory, List<String>>? categoryImages,
    int? currentTestIndex,
    bool? isInitialized,
  }) {
    return VisualHealthState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      categoryImages: categoryImages ?? this.categoryImages,
      currentTestIndex: currentTestIndex ?? this.currentTestIndex,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}
