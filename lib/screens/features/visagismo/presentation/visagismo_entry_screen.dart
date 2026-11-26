import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_totem_link.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_capture_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_photo_source_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_result_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_scanning_overlay.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gating screen: checks camera availability before ever creating the
/// camera preview. Without a camera (`VisagismoCubit.cameraEnabled` false)
/// the photo is picked from a gallery instead.
class VisagismoEntryScreen extends StatelessWidget {
  const VisagismoEntryScreen({super.key, this.totemLink});

  /// Link to a Tótem, when the host app has one (see [VisagismoTotemLink]).
  final VisagismoTotemLink? totemLink;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLocalizations.of(context).visagismoTitle),
        actions: [
          // Tótem link + "Repetir", only while showing a result.
          BlocBuilder<VisagismoCubit, VisagismoState>(
            buildWhen: (p, c) => p.step != c.step,
            builder: (context, state) => state.step == VisagismoStep.result
                ? VisagismoResultActions(totemLink: totemLink)
                : const SizedBox.shrink(),
          ),
        ],
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
              return context.read<VisagismoCubit>().cameraEnabled
                  ? const VisagismoCaptureScreen()
                  : const VisagismoPhotoSourceScreen();
            case VisagismoStep.scanning:
              return VisagismoScanningOverlay(
                imagePath: state.capturedImagePath!,
              );
            case VisagismoStep.result:
              return VisagismoResultScreen(totemLink: totemLink);
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
    final l10n = AppLocalizations.of(context);

    String message;
    Widget? action;

    if (state.cameraPermissionDenied) {
      message = l10n.visagismoCameraPermissionBody;
      action = ElevatedButton(
        onPressed: () => openAppSettings(),
        child: Text(l10n.visagismoOpenSettings),
      );
    } else {
      message = l10n.visagismoNoCamera;
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
              child: Text(l10n.visagismoRetry),
            ),
          ],
        ),
      ),
    );
  }
}
