import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_availability.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

/// Minimum time the "scanning" overlay stays up after a capture, purely for
/// showmanship (a FaceID-style effect) — the real ML Kit detection usually
/// finishes well under this, but revealing the result the instant it's ready
/// would make the scan animation look like a glitch rather than a feature.
const Duration _kMinScanDuration = Duration(milliseconds: 1600);

class VisagismoCubit extends Cubit<VisagismoState> {
  VisagismoCubit({VisagismoCatalogRepository? catalogRepository})
    : _catalogRepository = catalogRepository ?? VisagismoCatalogRepository(),
      super(const VisagismoState()) {
    _checkAvailability();
  }

  final VisagismoCatalogRepository _catalogRepository;
  FaceDetector? _faceDetector;

  Future<void> _checkAvailability() async {
    emit(state.copyWith(step: VisagismoStep.checkingAvailability));

    final permissionGranted = await Permission.camera.request().isGranted;
    if (!permissionGranted) {
      emit(
        state.copyWith(
          step: VisagismoStep.unavailable,
          availability: const VisagismoAvailability(hasFrontCamera: false),
          cameraPermissionDenied: true,
        ),
      );
      return;
    }

    bool hasFrontCamera = false;
    try {
      final cameras = await availableCameras();
      hasFrontCamera = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    } catch (_) {
      hasFrontCamera = false;
    }

    final availability = VisagismoAvailability(hasFrontCamera: hasFrontCamera);
    emit(
      state.copyWith(
        availability: availability,
        cameraPermissionDenied: false,
        step: hasFrontCamera ? VisagismoStep.capture : VisagismoStep.unavailable,
      ),
    );
    if (hasFrontCamera) {
      unawaited(_loadCatalog());
    }
  }

  Future<void> retryAvailabilityCheck() => _checkAvailability();

  Future<void> _loadCatalog() async {
    try {
      final catalog = await _catalogRepository.fetchCatalog();
      emit(state.copyWith(catalog: catalog));
    } catch (_) {
      // Catalog is advisory (frame suggestions); a hiccup here shouldn't
      // block the capture flow itself.
    }
  }

  /// Called by the capture screen once it has a JPEG on disk. Runs ML Kit
  /// face detection, derives measurements, and classifies — all while the
  /// scanning overlay plays, with a minimum duration so the effect always
  /// reads as intentional rather than an unlucky-fast flash.
  Future<void> onPhotoCaptured(String jpegPath) async {
    emit(
      state.copyWith(
        step: VisagismoStep.scanning,
        capturedImagePath: jpegPath,
        lastClassification: null,
      ),
    );

    final minDelay = Future<void>.delayed(_kMinScanDuration);
    final classification = await _classify(jpegPath);
    await minDelay;

    if (isClosed) return;
    emit(
      state.copyWith(
        step: VisagismoStep.result,
        lastClassification: classification,
      ),
    );
  }

  Future<FaceShapeResult?> _classify(String jpegPath) async {
    try {
      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await _faceDetector!.processImage(
        InputImage.fromFilePath(jpegPath),
      );
      if (faces.isEmpty) return null;
      final measurements = faceMeasurementsFromFace(faces.first);
      if (measurements == null) return null;
      return classifyFaceShape(measurements);
    } catch (_) {
      return null;
    }
  }

  void retakePhoto() {
    final oldPath = state.capturedImagePath;
    if (oldPath != null) {
      // Best-effort cleanup — these live under the app's own cache/temp
      // dir, not the gallery, so losing one on a rare failure is harmless.
      unawaited(_deleteQuietly(oldPath));
    }
    emit(
      state.copyWith(
        step: VisagismoStep.capture,
        capturedImagePath: null,
        lastClassification: null,
      ),
    );
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<bool> isFrameUnlocked(FrameCatalogItem item) =>
      _catalogRepository.isFrameUnlockedForCurrentOptica(
        item.frameId,
        item.tier,
      );

  @override
  Future<void> close() {
    _faceDetector?.close();
    return super.close();
  }
}
