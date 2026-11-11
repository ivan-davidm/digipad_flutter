import 'package:flutter/material.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

import '../models/simulation_scenario.dart';

/// Panel for selecting correction lenses.
class LensSelectorPanel extends StatelessWidget {
  final List<CorrectionLens> lenses;
  final CorrectionLens? selectedLens;
  final void Function(CorrectionLens) onLensSelected;

  const LensSelectorPanel({
    super.key,
    required this.lenses,
    required this.selectedLens,
    required this.onLensSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (lenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.lensesAvailable(0),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: lenses.map((lens) {
          final isSelected = selectedLens?.id == lens.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LensCard(
              lens: lens,
              isSelected: isSelected,
              onTap: () => onLensSelected(lens),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual lens card widget.
class _LensCard extends StatelessWidget {
  final CorrectionLens lens;
  final bool isSelected;
  final VoidCallback onTap;

  const _LensCard({
    required this.lens,
    required this.isSelected,
    required this.onTap,
  });

  Color get _qualityColor {
    switch (lens.quality) {
      case LensQuality.economy:
        return Colors.grey;
      case LensQuality.standard:
        return Colors.blue;
      case LensQuality.good:
        return Colors.green;
      case LensQuality.premium:
        return Colors.amber;
    }
  }

  IconData get _qualityIcon {
    switch (lens.quality) {
      case LensQuality.economy:
        return Icons.star_border_outlined;
      case LensQuality.standard:
        return Icons.star_half_outlined;
      case LensQuality.good:
        return Icons.star_outlined;
      case LensQuality.premium:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _qualityColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? _qualityColor
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _qualityColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _qualityIcon,
                      color: isSelected
                          ? _qualityColor
                          : Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _localizedLensName(context, lens),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _qualityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _localizedQualityLabel(context, lens.quality),
                    style: TextStyle(
                      color: _qualityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizedLensName(BuildContext context, CorrectionLens lens) {
    switch (lens.name) {
      case 'monofocal_near':
        return context.l10n.simLensMonofocalNear;
      case 'monofocal_far':
        return context.l10n.simLensMonofocalFar;
      case 'invisible':
        return context.l10n.simLensInvisibleBifocal;
      case 'multifocal':
        return context.l10n.simLensMultifocal;
      case 'anti_reflective':
        return context.l10n.simLensWithAR;
      case 'drivewear':
        return context.l10n.simCatDriveWear;
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
      case 'economic':
        return context.l10n.simQualityEconomy;
      case 'standard':
        return context.l10n.simQualityStandard;
      case 'good':
        return context.l10n.simQualityGood;
      case 'premium':
        return context.l10n.simQualityPremium;
      case 'progressive':
        return context.l10n.simLensProgressive;
      case 'sin_lente':
        return context.l10n.simLensNoLens;
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

  String _localizedQualityLabel(BuildContext context, LensQuality quality) {
    switch (quality) {
      case LensQuality.economy:
        return context.l10n.simQualityEconomy;
      case LensQuality.standard:
        return context.l10n.simQualityStandard;
      case LensQuality.good:
        return context.l10n.simQualityGood;
      case LensQuality.premium:
        return context.l10n.simQualityPremium;
    }
  }
}
