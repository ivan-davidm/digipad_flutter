import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_capture_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_result_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_scanning_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gating screen: checks camera availability before ever creating the
/// camera preview.
class VisagismoEntryScreen extends StatelessWidget {
  const VisagismoEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Visagismo'),
      ),
      body: BlocBuilder<VisagismoCubit, VisagismoState>(
        builder: (context, state) {
          switch (state.step) {
            case VisagismoStep.checkingAvailability:
              return const Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              );
            case VisagismoStep.unavailable:
              return _UnavailableView(state: state);
            case VisagismoStep.capture:
              return const VisagismoCaptureScreen();
            case VisagismoStep.scanning:
              return VisagismoScanningOverlay(
                imagePath: state.capturedImagePath!,
              );
            case VisagismoStep.result:
              return const VisagismoResultScreen();
          }
        },
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.state});

  final VisagismoState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VisagismoCubit>();

    String message;
    Widget? action;

    if (state.cameraPermissionDenied) {
      message = 'Esta función necesita permiso de cámara para funcionar. '
          'Activalo en los ajustes del dispositivo.';
      action = ElevatedButton(
        onPressed: () => openAppSettings(),
        child: const Text('Abrir ajustes'),
      );
    } else {
      message = 'No se detectó una cámara frontal disponible en este '
          'dispositivo. La prueba de visagismo necesita una cámara frontal '
          'para funcionar.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => cubit.retryAvailabilityCheck(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
