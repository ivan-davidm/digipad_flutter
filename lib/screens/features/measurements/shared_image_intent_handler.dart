import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'optical_editor_screen.dart';
import 'optical_logic_controller.dart';

/// Lets the client open a photo that arrived through another app — e.g. a
/// photo received in WhatsApp — directly into the measurement editor, via
/// Android's native "Share" sheet (registered as a SEND/SEND_MULTIPLE target
/// for `image/*` in AndroidManifest.xml).
///
/// These photos were never captured with the physical reference accessory,
/// so there's nothing to auto-detect — they go straight into the same
/// manual-calibration flow as the measurements hub's "Medición remota" tile
/// (`MeasurementMode.sinAccesorio`): empty `detections`, and
/// `OpticalController.initialize` seeds default pupil/lens markers in the
/// middle of the image for the user to drag into place and calibrate via the
/// frame-width field.
class SharedImageIntentHandler {
  SharedImageIntentHandler(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  /// Call once, after the app is past activation (e.g. in the home screen's
  /// `initState`) — a shared photo shouldn't jump the activation gate.
  void start() {
    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleShared,
      onError: (_) {},
    );
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleShared(List<SharedMediaFile> files) {
    String? imagePath;
    for (final file in files) {
      if (file.type == SharedMediaType.image) {
        imagePath = file.path;
        break;
      }
    }
    if (imagePath == null) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => OpticalEditorScreen(
          imagePath: imagePath!,
          detections: const {},
          mode: MeasurementMode.sinAccesorio,
        ),
      ),
    );
  }

  void dispose() {
    _mediaSub?.cancel();
  }
}
