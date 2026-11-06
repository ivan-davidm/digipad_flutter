import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_availability.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';

enum VisagismoStep { checkingAvailability, unavailable, capture, scanning, result }

class VisagismoState {
  final VisagismoStep step;
  final VisagismoAvailability? availability;
  final bool cameraPermissionDenied;
  final String? capturedImagePath;
  final FaceShapeResult? lastClassification;
  final List<FrameCatalogItem> catalog;

  const VisagismoState({
    this.step = VisagismoStep.checkingAvailability,
    this.availability,
    this.cameraPermissionDenied = false,
    this.capturedImagePath,
    this.lastClassification,
    this.catalog = const [],
  });

  VisagismoState copyWith({
    VisagismoStep? step,
    Object? availability = _sentinel,
    bool? cameraPermissionDenied,
    Object? capturedImagePath = _sentinel,
    Object? lastClassification = _sentinel,
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
      lastClassification: lastClassification == _sentinel
          ? this.lastClassification
          : lastClassification as FaceShapeResult?,
      catalog: catalog ?? this.catalog,
    );
  }

  static const _sentinel = Object();
}
