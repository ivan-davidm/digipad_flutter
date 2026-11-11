/// Snapshot of whether this device can run the visagismo capture flow.
///
/// The flow now runs entirely through Flutter's own `camera` plugin (no
/// native AR bridge), so the only real precondition is "is there a front
/// camera at all" — resolved from `availableCameras()`, same source
/// `vm_camera_screen.dart` already uses for its own camera selection.
class VisagismoAvailability {
  final bool hasFrontCamera;

  const VisagismoAvailability({required this.hasFrontCamera});
}
