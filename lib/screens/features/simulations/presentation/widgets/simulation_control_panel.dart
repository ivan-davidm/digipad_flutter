import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

import '../../cubit/simulations_cubit.dart';
import '../../cubit/simulations_state.dart';
import '../../models/simulation_scenario.dart';
import '../../widgets/lens_selector_panel.dart';

class SimulationControlPanel extends StatelessWidget {
  final SimulationsState state;
  final SimulationCategory category;
  final SimulationScenario scenario;
  final CorrectionLens? selectedLens;
  final ValueChanged<CorrectionLens> onLensSelected;

  /// Photochromic-only: adaptation-speed tier and its callbacks.
  final PhotoAdaptSpeed adaptSpeed;
  final ValueChanged<PhotoAdaptSpeed>? onAdaptSpeedChanged;
  final VoidCallback? onReplayAdaptation;

  const SimulationControlPanel({
    super.key,
    required this.state,
    required this.category,
    required this.scenario,
    required this.selectedLens,
    required this.onLensSelected,
    this.adaptSpeed = PhotoAdaptSpeed.buena,
    this.onAdaptSpeedChanged,
    this.onReplayAdaptation,
  });

  @override
  Widget build(BuildContext context) {
    if (scenario.correctionLenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final isPhotochromic = category.id == 'photochromic';
    final isTint = category.id == 'tint';
    final isLensMode = state.isLensDraggingMode;
    final isStaticMode = ['myopia', 'aspheric', 'multifocal', 'bifocal'].contains(category.id);

    Widget selectorWidget;
    if (isPhotochromic) {
      selectorWidget = _PhotochromicColorPicker(
        lenses: scenario.correctionLenses,
        selectedLens: selectedLens,
        onLensSelected: onLensSelected,
      );
    } else {
      selectorWidget = LensSelectorPanel(
        lenses: scenario.correctionLenses,
        selectedLens: selectedLens,
        onLensSelected: onLensSelected,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPhotochromic)
                Text(
                  context.l10n.selectLensLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (!isPhotochromic) const SizedBox(height: 20),

              // Selector and Controls Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: selectorWidget),

                  // Show extra controls (radius/divider) only if NOT in static mode and NOT photochromic
                  if (!isStaticMode && !isPhotochromic) ...[
                    const SizedBox(width: 32),

                    Container(
                      height: 120,
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),

                    const SizedBox(width: 32),

                    if (isLensMode)
                      _buildLensModeControls(context)
                    else
                      _buildDividerModeControls(context, isTint),
                  ],
                ],
              ),

              // Photochromic adaptation-speed tier (Estándar / Buena / Premium)
              if (isPhotochromic) ...[
                const SizedBox(height: 18),
                _PhotoAdaptSpeedRow(
                  selected: adaptSpeed,
                  onChanged: onAdaptSpeedChanged,
                  onReplay: onReplayAdaptation,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLensModeControls(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lens Size Control
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lens Size',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 32,
                  ),
                  onPressed: () {
                    final newRadius = (state.lensRadius - 20).clamp(
                      50.0,
                      400.0,
                    );
                    context.read<SimulationsCubit>().setLensRadius(newRadius);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.lensRadius.toInt()}px',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 32,
                  ),
                  onPressed: () {
                    final newRadius = (state.lensRadius + 20).clamp(
                      50.0,
                      400.0,
                    );
                    context.read<SimulationsCubit>().setLensRadius(newRadius);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (category.id == 'tint') _buildOpacitySlider(context),
          ],
        ),
      ],
    );
  }

  Widget _buildDividerModeControls(BuildContext context, bool isTint) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Orientation Toggle Button (Hide if Tint as it paints the whole image)
        if (!isTint)
          Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.dividerLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.read<SimulationsCubit>().toggleDividerOrientation();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    state.isVerticalDivider
                        ? Icons.swap_horiz
                        : Icons.swap_vert,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.isVerticalDivider
                  ? context.l10n.verticalLabel
                  : context.l10n.horizontalLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
              ),
            ),
          ],
        ),
        // Opacity Slider (Only if tint)
        if (isTint) _buildOpacitySlider(context),
      ],
    );
  }

  Widget _buildOpacitySlider(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.opacity,
              color: Colors.white.withValues(alpha: 0.7),
              size: 32,
            ),
            SizedBox(
              width: 180,
              height: 60,
              child: Slider(
                value: state.lensOpacity,
                min: 0.0,
                max: 0.5,
                divisions: 13,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  context.read<SimulationsCubit>().setLensOpacity(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotochromicColorPicker extends StatelessWidget {
  final List<CorrectionLens> lenses;
  final CorrectionLens? selectedLens;
  final ValueChanged<CorrectionLens> onLensSelected;

  const _PhotochromicColorPicker({
    required this.lenses,
    required this.selectedLens,
    required this.onLensSelected,
  });

  Color _colorForLens(CorrectionLens lens) {
    switch (lens.name) {
      case 'gray':
        return Colors.grey.shade600;
      case 'brown':
        return const Color(0xFF6D4C41);
      case 'green':
        return Colors.green.shade700;
      case 'sin_lente':
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: lenses.map((lens) {
          final isSelected = selectedLens?.id == lens.id;
          final color = _colorForLens(lens);
          final isSinLente = lens.name == 'sin_lente';

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => onLensSelected(lens),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: isSinLente ? 0.15 : 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSinLente ? Colors.transparent : color,
                        border: isSinLente
                            ? Border.all(color: Colors.white54, width: 1.5)
                            : null,
                      ),
                      child: isSinLente
                          ? const Icon(Icons.block, color: Colors.white54, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _localizedName(context, lens),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _localizedName(BuildContext context, CorrectionLens lens) {
    switch (lens.name) {
      case 'gray':
        return context.l10n.simColorGray;
      case 'brown':
        return context.l10n.simColorBrown;
      case 'green':
        return context.l10n.simColorGreen;
      case 'sunbalance':
        return context.l10n.simColorSunBalance;
      case 'yellow':
        return context.l10n.simColorYellow;
      case 'aqua':
        return context.l10n.simColorAqua;
      case 'blue':
        return context.l10n.simColorBlue;
      case 'orange':
        return context.l10n.simColorOrange;
      case 'red':
        return context.l10n.simColorRed;
      case 'sin_lente':
        return context.l10n.simLensNoLens;
      case 'economic':
        return context.l10n.simQualityEconomy;
      case 'standard':
        return context.l10n.simQualityStandard;
      case 'good':
        return context.l10n.simQualityGood;
      case 'premium':
        return context.l10n.simQualityPremium;
      case 'invisible':
        return context.l10n.simLensInvisibleBifocal;
      case 'multifocal':
        return context.l10n.simLensMultifocal;
      case 'anti_reflective':
        return context.l10n.simLensWithAR;
      case 'drivewear':
        return context.l10n.simCatDriveWear;
      case 'aspheric':
        return context.l10n.simLensAspheric;
      default:
        final diopterMatch = RegExp(r'^standard(_{1,2})(\d+)$').firstMatch(
          lens.name,
        );
        if (diopterMatch != null) {
          final sign = diopterMatch.group(1) == '__' ? '-' : '+';
          final value = diopterMatch.group(2);
          return '$sign$value.00 ${context.l10n.simQualityStandard}';
        }
        return lens.displayName;
    }
  }
}

/// Photochromic adaptation-speed tier picker: Estándar / Buena / Premium.
/// The premium tier fades the activated lens image in noticeably faster.
class _PhotoAdaptSpeedRow extends StatelessWidget {
  final PhotoAdaptSpeed selected;
  final ValueChanged<PhotoAdaptSpeed>? onChanged;
  final VoidCallback? onReplay;

  const _PhotoAdaptSpeedRow({
    required this.selected,
    required this.onChanged,
    required this.onReplay,
  });

  String _label(BuildContext context, PhotoAdaptSpeed s) {
    switch (s) {
      case PhotoAdaptSpeed.estandar:
        return context.l10n.simAdaptStandard;
      case PhotoAdaptSpeed.buena:
        return context.l10n.simAdaptGood;
      case PhotoAdaptSpeed.premium:
        return context.l10n.simAdaptPremium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.simAdaptLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PhotoAdaptSpeed.values.map((s) {
                final bool isSelected = s == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: onChanged == null ? null : () => onChanged!(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.amber.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        _label(context, s),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        IconButton(
          onPressed: onReplay,
          tooltip: context.l10n.simReplay,
          icon: const Icon(Icons.replay, color: Colors.white),
        ),
      ],
    );
  }
}
