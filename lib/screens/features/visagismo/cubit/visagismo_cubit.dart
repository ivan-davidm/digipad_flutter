import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:camera/camera.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_availability.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

/// Minimum time the "scanning" overlay stays up after a capture, purely for
/// showmanship (a FaceID-style effect) — the real ML Kit detection usually
/// finishes well under this, but revealing the result the instant it's ready
/// would make the scan animation look like a glitch rather than a feature.
const Duration _kMinScanDuration = Duration(milliseconds: 1600);

class VisagismoCubit extends Cubit<VisagismoState> {
  VisagismoCubit({
    VisagismoCatalogRepository? catalogRepository,
    this.cameraEnabled = true,
  }) : _catalogRepository = catalogRepository ?? VisagismoCatalogRepository(),
       super(const VisagismoState()) {
    _checkAvailability();
  }

  /// False: the photo comes only from a gallery (the app's internal gallery
  /// or the device's) — no camera permission, no camera preview. DigiTower 3D
  /// Premium runs on the Tótem, whose webcams are often low quality (client
  /// request 2026-11-26: no photos from the Tótem for now). The Remote
  /// Control keeps the camera.
  final bool cameraEnabled;

  final VisagismoCatalogRepository _catalogRepository;
  FaceDetector? _faceDetector;

  Future<void> _checkAvailability() async {
    emit(state.copyWith(step: VisagismoStep.checkingAvailability));

    if (!cameraEnabled) {
      emit(state.copyWith(step: VisagismoStep.capture));
      unawaited(_loadCatalog());
      return;
    }

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

    var hasFrontCamera = false;
    var hasBackCamera = false;
    try {
      final cameras = await availableCameras();
      hasFrontCamera = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      hasBackCamera = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      // Some devices report only "external" cameras: still usable.
      if (!hasFrontCamera && !hasBackCamera && cameras.isNotEmpty) {
        hasBackCamera = true;
      }
    } catch (_) {
      hasFrontCamera = false;
      hasBackCamera = false;
    }

    final availability = VisagismoAvailability(
      hasFrontCamera: hasFrontCamera,
      hasBackCamera: hasBackCamera,
    );
    emit(
      state.copyWith(
        availability: availability,
        cameraPermissionDenied: false,
        step: availability.hasAnyCamera
            ? VisagismoStep.capture
            : VisagismoStep.unavailable,
      ),
    );
    if (availability.hasAnyCamera) {
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
  Future<void> onPhotoCaptured(String jpegPath) =>
      _scan(jpegPath, fromCamera: true);

  /// Same as [onPhotoCaptured] for a photo picked from a gallery. The file is
  /// not ours: it is never deleted, and the result screen doesn't save it to
  /// the gallery again.
  Future<void> onPhotoPicked(String imagePath) =>
      _scan(imagePath, fromCamera: false);

  Future<void> _scan(String jpegPath, {required bool fromCamera}) async {
    emit(
      state.copyWith(
        step: VisagismoStep.scanning,
        capturedImagePath: jpegPath,
        capturedFromCamera: fromCamera,
        lastClassification: null,
        lastAnalysis: null,
      ),
    );

    final minDelay = Future<void>.delayed(_kMinScanDuration);
    final analysis = await _analyze(jpegPath);
    await minDelay;

    if (isClosed) return;
    emit(
      state.copyWith(
        step: VisagismoStep.result,
        lastClassification: analysis.shape,
        lastAnalysis: analysis,
      ),
    );
  }

  Future<FaceAnalysis> _analyze(String jpegPath) async {
    try {
      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          // Eye landmarks level the contour when the head is tilted sideways.
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await _faceDetector!.processImage(
        InputImage.fromFilePath(jpegPath),
      );
      return analyzeFaces(faces);
    } catch (e, st) {
      // Never report a detector failure as "no face": log it and carry it to
      // the result screen so it can be told apart (and diagnosed).
      debugPrint('[Visagismo] face detector failed: $e\n$st');
      return FaceAnalysis.detectorFailed(e);
    }
  }

  /// Back to the camera / gallery picker for another photo.
  void retakePhoto() {
    final oldPath = state.capturedImagePath;
    // Only camera captures are ours to delete — a picked photo may be in the
    // internal gallery.
    if (oldPath != null && state.capturedFromCamera) {
      // Best-effort cleanup — these live under the app's own cache/temp
      // dir, not the gallery, so losing one on a rare failure is harmless.
      unawaited(_deleteQuietly(oldPath));
    }
    emit(
      state.copyWith(
        step: VisagismoStep.capture,
        capturedImagePath: null,
        capturedFromCamera: false,
        lastClassification: null,
        lastAnalysis: null,
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
