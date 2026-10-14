import 'package:flutter_bloc/flutter_bloc.dart';
import 'lenses_3d_state.dart';

class Lenses3DCubit extends Cubit<Lenses3DState> {
  Lenses3DCubit() : super(const Lenses3DState());

  void copySettingsFrom(Lenses3DState otherState) {
    emit(
      state.copyWith(
        materialIndex: otherState.materialIndex,
        prescription: otherState.prescription,
        frameType: otherState.frameType,
        orientation: otherState.orientation,
      ),
    );
  }

  void selectSinGlasses() {
    emit(state.copyWith(prescription: 0));
  }

  void updateMaterialIndex(LensMaterialIndex materialIndex) {
    // Exit sin-glasses mode: default to prescription 1.
    int newPrescription = state.prescription == 0 ? 1 : state.prescription;
    final newState = state.copyWith(materialIndex: materialIndex, prescription: newPrescription);
    final clamped = newPrescription.clamp(newState.minPrescription, newState.maxPrescription);
    emit(state.copyWith(materialIndex: materialIndex, prescription: clamped));
  }

  void updatePrescription(int prescription) {
    final clamped = prescription.clamp(
      state.minPrescription,
      state.maxPrescription,
    );
    emit(state.copyWith(prescription: clamped));
  }

  void incrementPrescription() {
    if (state.prescription < state.maxPrescription) {
      emit(state.copyWith(prescription: state.prescription + 1));
    }
  }

  void decrementPrescription() {
    if (state.prescription > state.minPrescription) {
      emit(state.copyWith(prescription: state.prescription - 1));
    }
  }

  void updateFrameType(LensFrameType frameType) {
    final next = state.copyWith(frameType: frameType);
    final clamped = state.prescription.clamp(next.minPrescription, next.maxPrescription);
    emit(next.copyWith(prescription: clamped));
  }

  void updateOrientation(LensOrientation orientation) {
    emit(state.copyWith(orientation: orientation));
  }

  void updateOrientationByAngle(int angle) {
    final orientation = LensOrientation.values.firstWhere(
      (o) => o.angle == angle,
      orElse: () => LensOrientation.angle15,
    );
    emit(state.copyWith(orientation: orientation));
  }

  void setLoading(bool isLoading) {
    emit(state.copyWith(isLoading: isLoading));
  }

  void setError(String message) {
    emit(state.copyWith(errorMessage: message, isLoading: false));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
