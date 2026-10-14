import 'package:digipad_flutter/common/utils/responsive_utils.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_cubit.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_state.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/widgets/lens_image_viewer.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/widgets/lenses_3d_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

class Lenses3DScreen extends StatefulWidget {
  const Lenses3DScreen({super.key});

  @override
  State<Lenses3DScreen> createState() => _Lenses3DScreenState();
}

class _Lenses3DScreenState extends State<Lenses3DScreen> {
  late final Lenses3DCubit _leftCubit;
  late final Lenses3DCubit _rightCubit;

  LensOrientation _sharedOrientation = LensOrientation.angle01;

  @override
  void initState() {
    super.initState();
    _leftCubit = Lenses3DCubit();
    _rightCubit = Lenses3DCubit();
  }

  @override
  void dispose() {
    _leftCubit.close();
    _rightCubit.close();
    super.dispose();
  }

  void _updateOrientation(int angle) {
    final o = LensOrientation.values.firstWhere(
      (v) => v.angle == angle,
      orElse: () => LensOrientation.angle01,
    );
    setState(() => _sharedOrientation = o);
    _leftCubit.updateOrientationByAngle(angle);
    _rightCubit.updateOrientationByAngle(angle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return OrientationBuilder(
              builder: (context, orientation) {
                final responsive = context.responsive(constraints, orientation);
                return Text(
                  '${context.l10n.lensThicknessSimulator} — ${context.l10n.comparatorLabel}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: responsive.fontSize(18),
                  ),
                );
              },
            );
          },
        ),
        backgroundColor: Colors.greenAccent.shade200,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── TOP: Images (80%) ─────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BlocProvider.value(
                        value: _leftCubit,
                        child: _LensImagesView(label: context.l10n.lensLabelA),
                      ),
                    ),
                    Container(width: 2, color: Colors.white),
                    Expanded(
                      child: BlocProvider.value(
                        value: _rightCubit,
                        child: _LensImagesView(label: context.l10n.lensLabelB),
                      ),
                    ),
                  ],
                ),
                // Copy A → B button on the divider
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      heroTag: 'equal_btn',
                      elevation: 4,
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        _rightCubit.copySettingsFrom(_leftCubit.state);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.settingsCopied),
                            duration: const Duration(milliseconds: 800),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.grey.shade900,
                          ),
                        );
                      },
                      tooltip: context.l10n.copyAtoB,
                      child: const Text('=', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM: Controls (20%) ────────────────────────────────────
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade900,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SharedOrientationSlider(
                    orientation: _sharedOrientation,
                    onChanged: _updateOrientation,
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BlocProvider.value(
                            value: _leftCubit,
                            child: Lenses3DControlPanel(
                              label: context.l10n.lensLabelA,
                            ),
                          ),
                        ),
                        Container(width: 1, color: Colors.white12),
                        Expanded(
                          child: BlocProvider.value(
                            value: _rightCubit,
                            child: Lenses3DControlPanel(
                              label: context.l10n.lensLabelB,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared orientation slider ──────────────────────────────────────────────
class _SharedOrientationSlider extends StatelessWidget {
  final LensOrientation orientation;
  final ValueChanged<int> onChanged;

  const _SharedOrientationSlider({
    required this.orientation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.threesixty, color: Colors.greenAccent, size: 14),
            const SizedBox(width: 4),
            Text(
              context.l10n.sharedView,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.greenAccent,
                  inactiveTrackColor: Colors.grey.shade700,
                  thumbColor: Colors.greenAccent,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: orientation.angle.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                orientation.shortName,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Per-lens image area (detail + overview) ───────────────────────────────
class _LensImagesView extends StatefulWidget {
  final String label;

  const _LensImagesView({required this.label});

  @override
  State<_LensImagesView> createState() => _LensImagesViewState();
}

class _LensImagesViewState extends State<_LensImagesView> {
  final TransformationController _tc = TransformationController();
  Size _detailSize = Size.zero;
  bool _initialSet = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // Build matrix: scale s, centered on normalized image position (nx, ny).
  // For BoxFit.cover child filling _detailSize:
  //   tx = W * (0.5 - s * nx),  ty = H * (0.5 - s * ny)
  Matrix4 _buildMatrix(double s, double nx, double ny) {
    final W = _detailSize.width;
    final H = _detailSize.height;
    final m = Matrix4.identity();
    m.setEntry(0, 0, s);
    m.setEntry(1, 1, s);
    m.setEntry(0, 3, W * (0.5 - s * nx));
    m.setEntry(1, 3, H * (0.5 - s * ny));
    return m;
  }

  void _resetToCenter() {
    if (_detailSize == Size.zero) return;
    _tc.value = _buildMatrix(2.0, 0.5, 0.5);
  }

  void _navigateTo(TapUpDetails details, Size overviewSize) {
    // Overview uses BoxFit.cover: normalized widget position = normalized image position.
    final nx = (details.localPosition.dx / overviewSize.width).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / overviewSize.height).clamp(0.0, 1.0);
    final s = _tc.value.getMaxScaleOnAxis();
    _tc.value = _buildMatrix(s, nx, ny);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<Lenses3DCubit, Lenses3DState>(
      // Reset zoom when the lens type changes (not when orientation rotates).
      listenWhen: (prev, curr) =>
          prev.materialIndex != curr.materialIndex ||
          prev.prescription != curr.prescription ||
          prev.frameType != curr.frameType,
      listener: (ctx, st) => _resetToCenter(),
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel label
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.grey.shade300,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            // ── Detail view (top 60%, interactive) ──────────────────────
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  if (_detailSize != size) {
                    _detailSize = size;
                  }
                  if (!_initialSet) {
                    _initialSet = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _resetToCenter();
                    });
                  }
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: InteractiveViewer(
                            transformationController: _tc,
                            constrained: false,
                            minScale: 0.5,
                            maxScale: 8.0,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Image.asset(
                                state.currentImagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (imgCtx, e, st) => Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 32,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Material / prescription badge
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              state.prescription == 0
                                  ? context.l10n.sinGlasses
                                  : '${state.materialIndex.displayName} • ${state.prescription}D • ${state.frameType.displayName}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                        // Live zoom level
                        Positioned(
                          top: 6,
                          right: 6,
                          child: ValueListenableBuilder<Matrix4>(
                            valueListenable: _tc,
                            builder: (vlbCtx, matrix, child) {
                              final s = matrix.getMaxScaleOnAxis();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${s.toStringAsFixed(1)}×',
                                  style: const TextStyle(
                                      color: Colors.greenAccent, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        // Orientation badge
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.greenAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              state.orientation.shortName,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Overview (bottom 40%, tap to navigate) ───────────────────
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ovSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return LensImageViewer(
                    state: state,
                    onTapUp: (details) => _navigateTo(details, ovSize),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
