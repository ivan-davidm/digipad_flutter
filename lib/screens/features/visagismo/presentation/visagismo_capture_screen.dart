import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_frame_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Live front-camera preview + capture button. Plain `camera`-plugin
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
  List<CameraDescription> _cameras = [];
  CameraDescription? _activeCamera;
  FlashMode _flashMode = FlashMode.off;
  bool _flashSupported = true;
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
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'No se detectó ninguna cámara en este dispositivo.';
            _isInitializing = false;
          });
        }
        return;
      }
      _cameras = cameras;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      await _startController(front);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo iniciar la cámara.';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      // Front-facing lenses rarely have a real flash unit; probe instead of
      // assuming, so a device that proves otherwise still gets the button.
      bool flashSupported = camera.lensDirection != CameraLensDirection.front;
      if (flashSupported) {
        try {
          await controller.setFlashMode(_flashMode);
        } catch (_) {
          flashSupported = false;
        }
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _activeCamera = camera;
        _flashSupported = flashSupported;
        _isInitializing = false;
        _error = null;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _error = 'No se pudo iniciar la cámara.';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _switchCamera(CameraDescription camera) async {
    if (_isCapturing || camera == _activeCamera) return;
    setState(() => _isInitializing = true);
    await _startController(camera);
  }

  /// Simple toggle when there are only front/back lenses; cycles to "the
  /// other" one relative to whichever is active.
  void _toggleFrontBack() {
    final other = _cameras.firstWhere(
      (c) => c.lensDirection != _activeCamera?.lensDirection,
      orElse: () => _cameras.first,
    );
    _switchCamera(other);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || !_flashSupported) return;
    const order = [FlashMode.off, FlashMode.auto, FlashMode.torch];
    final next = order[(order.indexOf(_flashMode) + 1) % order.length];
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {
      if (mounted) setState(() => _flashSupported = false);
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
            content: const Text('Error al tomar la foto. Probá de nuevo.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleCameras = _cameras.length > 1;
    final hasExtraCameras = _cameras.length > 2;
    return Stack(
      children: [
        Positioned.fill(child: _buildPreview()),
        if (_controller != null) const _FaceGuideOverlay(),
        if (_controller != null)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  if (_flashSupported)
                    _CameraToolButton(
                      icon: switch (_flashMode) {
                        FlashMode.off => Icons.flash_off,
                        FlashMode.auto => Icons.flash_auto,
                        _ => Icons.flash_on,
                      },
                      tooltip: 'Flash',
                      onTap: _cycleFlash,
                    ),
                  if (hasExtraCameras)
                    _CameraToolButton(
                      icon: Icons.videocam_outlined,
                      tooltip: 'Elegir cámara',
                      onTap: () => _showCameraPicker(context),
                    )
                  else if (hasMultipleCameras)
                    _CameraToolButton(
                      icon: Icons.cameraswitch_outlined,
                      tooltip: 'Cambiar cámara',
                      onTap: _toggleFrontBack,
                    ),
                ],
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

  String _cameraLabel(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return 'Cámara frontal';
      case CameraLensDirection.back:
        return 'Cámara trasera';
      case CameraLensDirection.external:
        return 'Cámara externa (USB)';
    }
  }

  void _showCameraPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _cameras.map((camera) {
            final isActive = camera == _activeCamera;
            return ListTile(
              leading: Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isActive ? Colors.deepPurpleAccent : Colors.white54,
              ),
              title: Text(
                _cameraLabel(camera),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _switchCamera(camera);
              },
            );
          }).toList(),
        ),
      ),
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
                child: const Text('Reintentar'),
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
    // Front camera preview feels wrong unmirrored — users expect a selfie
    // mirror, like every other camera app's front-facing preview.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(math.pi),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// Decorative oval guide so the client knows where to position their face —
/// purely a framing aid, not tied to any real detection (that happens after
/// capture).
class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: kFaceGuideWidth,
          height: kFaceGuideHeight,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(kFaceGuideBorderRadius),
            border: Border.all(color: Colors.white38, width: 2),
          ),
        ),
      ),
    );
  }
}

class _CameraToolButton extends StatelessWidget {
  const _CameraToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black45,
            ),
            child: Icon(icon, color: Colors.white),
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
