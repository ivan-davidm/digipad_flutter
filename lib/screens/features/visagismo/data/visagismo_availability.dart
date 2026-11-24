/// Snapshot of whether this device can run the visagismo capture flow.
///
/// The flow runs entirely through Flutter's own `camera` plugin (no native AR
/// bridge). It starts on the rear camera (easier to aim at the client) and
/// offers the front one as an alternative, so the only real precondition is
/// "is there at least one camera" — resolved from `availableCameras()`.
class VisagismoAvailability {
  final bool hasFrontCamera;
  final bool hasBackCamera;

  const VisagismoAvailability({
    required this.hasFrontCamera,
    this.hasBackCamera = false,
  });

  bool get hasAnyCamera => hasFrontCamera || hasBackCamera;

  /// The capture screen only shows a flip button when there is a choice.
  bool get canFlip => hasFrontCamera && hasBackCamera;
}
