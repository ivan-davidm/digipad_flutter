import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_cubit.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

/// Overview widget for a single lens panel.
/// Shows the full image, handles swipe-to-rotate orientation gesture,
/// and fires [onTapUp] so the parent can navigate the detail zoom.
class LensImageViewer extends StatefulWidget {
  final Lenses3DState state;
  final void Function(TapUpDetails)? onTapUp;

  const LensImageViewer({
    super.key,
    required this.state,
    this.onTapUp,
  });

  @override
  State<LensImageViewer> createState() => _LensImageViewerState();
}

class _LensImageViewerState extends State<LensImageViewer> {
  double _virtualAngle = 1.0;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _virtualAngle = widget.state.orientation.angle.toDouble();
  }

  @override
  void didUpdateWidget(LensImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.orientation.angle != widget.state.orientation.angle) {
      _virtualAngle = widget.state.orientation.angle.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<Lenses3DCubit>();

    return Listener(
      onPointerDown: (_) => _pointerCount++,
      onPointerUp: (_) => _pointerCount--,
      onPointerCancel: (_) => _pointerCount--,
      child: GestureDetector(
      onPanStart: (_) {
        _virtualAngle = widget.state.orientation.angle.toDouble();
      },
      onPanUpdate: (details) {
        if (_pointerCount > 1) return; // ignore multi-touch / pinch on overview
        final dx = details.delta.dx;
        final dy = details.delta.dy;
        double newAngle = _virtualAngle;

        const hSens = 0.05;
        const vSens = 0.05;

        if (_virtualAngle < 14.5) {
          newAngle += dx * hSens;
          if (newAngle > 15.0) newAngle = 15.0;
        } else if (_virtualAngle > 15.5) {
          newAngle -= dy * vSens;
          if (newAngle < 15.0) newAngle = 15.0;
        } else {
          if (dx.abs() > dy.abs()) {
            if (dx < 0) newAngle += dx * hSens;
          } else {
            if (dy < 0) newAngle -= dy * vSens;
          }
        }

        newAngle = newAngle.clamp(1.0, 20.0);
        _virtualAngle = newAngle;

        final target = _virtualAngle.round();
        if (target != widget.state.orientation.angle) {
          cubit.updateOrientationByAngle(target);
        }
      },
      onTapUp: widget.onTapUp,
      child: Container(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              widget.state.currentImagePath,
              fit: BoxFit.cover,
              errorBuilder: (context2, e, st) => Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 28,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            // Material / prescription info
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.state.prescription == 0
                      ? context.l10n.sinGlasses
                      : '${widget.state.materialIndex.displayName} • ${widget.state.prescription}D',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ),
            // Orientation badge
            Positioned(
              bottom: 4,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  widget.state.orientation.shortName,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Tap-hint icon
            Positioned(
              bottom: 4,
              right: 6,
              child: Icon(
                Icons.touch_app_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    ), // GestureDetector
    ); // Listener
  }
}
