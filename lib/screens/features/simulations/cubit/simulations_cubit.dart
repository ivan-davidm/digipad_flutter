import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/simulation_data.dart';
import '../models/simulation_scenario.dart';
import 'simulations_state.dart';

/// Cubit for managing simulations feature state.
class SimulationsCubit extends Cubit<SimulationsState> {
  SimulationsCubit() : super(SimulationsState.initial());

  /// Get all available categories.
  List<SimulationCategory> get categories => SimulationData.categories;

  /// Select a visual problem category.
  void selectCategory(SimulationCategory category) {
    emit(
      state.copyWith(
        selectedCategory: category,
        clearScenario: true,
        clearLens: true,
      ),
    );
  }

  /// Select a specific scenario within the current category.
  void selectScenario(SimulationScenario scenario) {
    // Progressives (multifocal) default to the "Good" quality tier;
    // everything else defaults to the first available lens.
    CorrectionLens? defaultLens;
    if (scenario.correctionLenses.isNotEmpty) {
      defaultLens = state.selectedCategory?.id == 'multifocal'
          ? scenario.correctionLenses.firstWhere(
              (lens) => lens.quality == LensQuality.good,
              orElse: () => scenario.correctionLenses[0],
            )
          : scenario.correctionLenses[0];
    }
    emit(
      state.copyWith(
        selectedScenario: scenario,
        selectedLens: defaultLens,
        clearError: true,
      ),
    );
  }

  /// Select a correction lens for the current scenario.
  void selectLens(CorrectionLens lens) {
    emit(state.copyWith(selectedLens: lens));
  }

  /// Move the divider to a new position (0.0 to 1.0).
  void moveDivider(double position) {
    emit(state.copyWith(dividerPosition: position.clamp(0.0, 1.0)));
  }

  /// Toggle the divider orientation between vertical and horizontal.
  void toggleDividerOrientation() {
    emit(state.copyWith(isVerticalDivider: !state.isVerticalDivider));
  }

  /// Set the divider orientation.
  void setDividerOrientation(bool isVertical) {
    emit(state.copyWith(isVerticalDivider: isVertical));
  }

  /// Set the lens opacity.
  void setLensOpacity(double opacity) {
    emit(state.copyWith(lensOpacity: opacity.clamp(0.0, 1.0)));
  }

  /// Set dragging state.
  void setDragging(bool isDragging) {
    emit(state.copyWith(isDragging: isDragging));
  }

  /// Move the draggable lens to a new position.
  void moveLens(Offset position) {
    emit(state.copyWith(lensPosition: position));
  }

  /// Set lens position.
  void setLensPosition(Offset position) {
    emit(state.copyWith(lensPosition: position));
  }

  /// Set lens radius.
  void setLensRadius(double radius) {
    emit(state.copyWith(lensRadius: radius.clamp(50.0, 400.0)));
  }

  /// Toggle between lens dragging mode and divider mode.
  void toggleInteractionMode() {
    emit(state.copyWith(isLensDraggingMode: !state.isLensDraggingMode));
  }

  /// Set interaction mode (true = lens dragging, false = divider).
  void setInteractionMode(bool isLensMode) {
    emit(state.copyWith(isLensDraggingMode: isLensMode));
  }

  /// Set loading state.
  void setLoading(bool isLoading) {
    emit(state.copyWith(isLoading: isLoading));
  }

  /// Set error message.
  void setError(String message) {
    emit(state.copyWith(errorMessage: message, isLoading: false));
  }

  /// Clear error.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  /// Reset to initial state (category selection).
  void reset() {
    emit(SimulationsState.initial());
  }

  /// Go back to category selection.
  void goToCategories() {
    emit(SimulationsState.initial());
  }

  /// Go back to scenario selection.
  void goToScenarios() {
    emit(state.copyWith(clearLens: true));
  }
}
