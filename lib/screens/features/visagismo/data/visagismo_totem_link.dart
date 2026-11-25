import 'dart:io';

import 'package:flutter/widgets.dart';

/// What the visagismo screens need to know about the link to a Tótem.
class VisagismoTotemStatus {
  const VisagismoTotemStatus({
    this.connected = false,
    this.sending = false,
    this.totemName,
  });

  static const disconnected = VisagismoTotemStatus();

  final bool connected;

  /// A photo is on its way.
  final bool sending;

  /// Name of the connected Tótem, when known.
  final String? totemName;
}

/// Optional link from the visagismo to a Tótem, provided by the host app.
///
/// The visagismo module is the same code in both apps (DigiTower 3D Remote
/// Control and DigiTower 3D Premium). Only the Remote Control sends photos to
/// a Tótem: it passes an implementation of this to `VisagismoEntryScreen`.
/// DigiTower 3D Premium runs ON the Tótem, so it passes nothing — the screens
/// then just save to the local gallery and hide every Tótem control.
abstract class VisagismoTotemLink {
  VisagismoTotemStatus get status;

  /// Emits whenever [status] changes.
  Stream<VisagismoTotemStatus> get statusChanges;

  /// Sends [photo]. True only when the Tótem confirmed it.
  Future<bool> send(File photo);

  /// Opens the host app's pairing screen.
  void openPairing(BuildContext context);
}
