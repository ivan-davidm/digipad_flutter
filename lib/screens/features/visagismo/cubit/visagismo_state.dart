import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_availability.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';

/// [capture] = waiting for a photo: the live camera, or the gallery picker
/// when the host app turned the camera off (see `VisagismoCubit.cameraEnabled`).
enum VisagismoStep { checkingAvailability, unavailable, capture, scanning, result }

class VisagismoState {
  final VisagismoStep step;
  final VisagismoAvailability? availability;
  final bool cameraPermissionDenied;
  final String? capturedImagePath;

  /// [capturedImagePath] is a camera capture (a temp file this module owns)
  /// rather than a photo picked from a gallery (someone else's file).
  final bool capturedFromCamera;
  final FaceShapeResult? lastClassification;

  /// Full result of the last photo (measurements, head pose, why it failed).
  final FaceAnalysis? lastAnalysis;
  final List<FrameCatalogItem> catalog;

  const VisagismoState({
    this.step = VisagismoStep.checkingAvailability,
    this.availability,
    this.cameraPermissionDenied = false,
    this.capturedImagePath,
    this.capturedFromCamera = false,
    this.lastClassification,
    this.lastAnalysis,
    this.catalog = const [],
  });

  VisagismoState copyWith({
    VisagismoStep? step,
    Object? availability = _sentinel,
    bool? cameraPermissionDenied,
    Object? capturedImagePath = _sentinel,
    bool? capturedFromCamera,
    Object? lastClassification = _sentinel,
    Object? lastAnalysis = _sentinel,
    List<FrameCatalogItem>? catalog,
  }) {
    return VisagismoState(
      step: step ?? this.step,
      availability: availability == _sentinel
          ? this.availability
          : availability as VisagismoAvailability?,
      cameraPermissionDenied:
          cameraPermissionDenied ?? this.cameraPermissionDenied,
      capturedImagePath: capturedImagePath == _sentinel
          ? this.capturedImagePath
          : capturedImagePath as String?,
      capturedFromCamera: capturedFromCamera ?? this.capturedFromCamera,
      lastClassification: lastClassification == _sentinel
          ? this.lastClassification
          : lastClassification as FaceShapeResult?,
      lastAnalysis: lastAnalysis == _sentinel
          ? this.lastAnalysis
          : lastAnalysis as FaceAnalysis?,
      catalog: catalog ?? this.catalog,
    );
  }

  static const _sentinel = Object();
}
