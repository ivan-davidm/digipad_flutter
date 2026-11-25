import 'package:camera/camera.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_frame_guide.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Live camera preview + capture button. Starts on the REAR camera (the
/// operator aims it at the client and can see the screen); a button flips to
/// the front camera when the device has one. Plain `camera`-plugin
/// `CameraPreview` (no custom native view) — replaces the earlier
/// ARCore/SceneView-based live AR screen, which hit an unresolved native
/// `AR_ERROR_TEXTURE_NOT_SET` bug on real hardware. This flow captures a
/// single photo instead of rendering a live 3D overlay; the "magic" happens
/// after capture (see `VisagismoScanningOverlay`).
class VisagismoCaptureScreen extends StatefulWidget {
  const VisagismoCaptureScreen({super.key});

  @override
  State<VisagismoCaptureScreen> createState() =>
      _VisagismoCaptureScreenState();
}

class _VisagismoCaptureScreenState extends State<VisagismoCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraLensDirection _direction = CameraLensDirection.back;

  /// The opened camera is an external one (USB webcam, e.g. on a Tótem).
  bool _isExternal = false;
  bool _canFlip = false;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      final hasFront = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final hasBack = cameras.any(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      // Honour the requested side when the device has it; otherwise use
      // whatever camera exists.
      final wanted = cameras.where((c) => c.lensDirection == _direction);
      final camera = wanted.isNotEmpty ? wanted.first : cameras.first;
      _direction = camera.lensDirection == CameraLensDirection.front
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      _isExternal = camera.lensDirection == CameraLensDirection.external;
      _canFlip = hasFront && hasBack;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).visagismoCameraStartFailed;
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final controller = _controller;
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused) {
      if (_isCapturing) return;
      if (controller != null) {
        _controller = null;
        controller.dispose();
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (_controller == null && _error == null) _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final xfile = await controller.takePicture();
      if (!mounted) return;
      context.read<VisagismoCubit>().onPhotoCaptured(xfile.path);
    } catch (_) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).visagismoCaptureFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _flipCamera() async {
    if (_isCapturing || _isInitializing || !_canFlip) return;
    final old = _controller;
    setState(() {
      _controller = null;
      _direction = _direction == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await old?.dispose();
    await _initCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildPreview()),
        if (_controller != null) const _FaceGuideOverlay(),
        if (_controller != null && _canFlip)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
              child: IconButton(
                tooltip: _direction == CameraLensDirection.back
                    ? AppLocalizations.of(context).visagismoFrontCamera
                    : AppLocalizations.of(context).visagismoRearCamera,
                icon: const Icon(Icons.flip_camera_android_rounded,
                    color: Colors.white),
                onPressed: _flipCamera,
              ),
            ),
          ),
        if (_controller != null)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _CaptureButton(
                isBusy: _isCapturing,
                onTap: _isCapturing ? null : _capture,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initCamera,
                child: Text(AppLocalizations.of(context).visagismoRetry),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    }
    // No extra flip for the built-in cameras: the camera plugin ALREADY
    // mirrors the front camera's preview (selfie mirror; camera_android_camerax
    // does it in `ImageReaderRotatedPreview`, the SurfaceTexture path
    // natively). Flipping it again — as this screen used to — undid the
    // mirror, so a hand moving the phone "like for a selfie" sent the face the
    // other way (field reports 2026-11-25). The rear camera shows the scene as
    // it is.
    //
    // An EXTERNAL camera (USB webcam on a Tótem) faces the client like a
    // selfie camera, but the plugin does not mirror it — so we do (product
    // decision 2026-11-25). Only the preview: the photo is analysed and saved
    // as captured, like the front camera's.
    final preview = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
    if (!_isExternal) return preview;
    return Transform.flip(flipX: true, child: preview);
  }
}

/// Decorative oval guide so the client knows where to position their face —
/// purely a framing aid, not tied to any real detection (that happens after
/// capture).
class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    final size = faceGuideSize(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(faceGuideBorderRadius(context)),
            border: Border.all(color: Colors.white38, width: 2),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap, required this.isBusy});

  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.deepPurpleAccent, width: 4),
        ),
        child: isBusy
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.deepPurpleAccent,
                ),
              )
            : null,
      ),
    );
  }
}
