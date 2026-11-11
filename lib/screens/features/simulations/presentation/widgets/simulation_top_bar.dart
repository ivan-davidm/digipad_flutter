import 'package:digipad_flutter/common/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import '../simulation_strings.dart';

import '../../models/simulation_scenario.dart';

class SimulationTopBar extends StatelessWidget {
  final SimulationScenario scenario;
  final SimulationCategory category;
  final Color categoryColor;
  final VoidCallback onBack;
  final VoidCallback? onToggleMode;
  final bool isLensMode;

  const SimulationTopBar({
    super.key,
    required this.scenario,
    required this.category,
    required this.categoryColor,
    required this.onBack,
    this.onToggleMode,
    this.isLensMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OrientationBuilder(
          builder: (context, orientation) {
            final responsive = context.responsive(constraints, orientation);
            final isTablet = responsive.isTablet;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    category.color.withValues(alpha: 0.95),
                    category.color.withValues(alpha: 0.8),
                    category.color.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: responsive.padding(
                    EdgeInsets.fromLTRB(16, 16, 24, isTablet ? 40 : 24),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.25),
                          shape: const CircleBorder(),
                        ),
                        icon: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: responsive.iconSize(isTablet ? 28 : 20),
                        ),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      // Category Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          category.icon,
                          color: Colors.white,
                          size: responsive.iconSize(isTablet ? 40 : 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              SimulationStrings.categoryName(context, category),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.fontSize(isTablet ? 48 : 34),
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3.0,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              SimulationStrings.scenarioName(context, scenario),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: responsive.fontSize(isTablet ? 28 : 20),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onToggleMode != null &&
                          scenario.correctionLenses.isNotEmpty &&
                          !['myopia', 'aspheric', 'bifocal', 'multifocal', 'photochromic']
                              .contains(
                            category.id,
                          ))
                        _buildModeToggle(context, responsive),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeToggle(BuildContext context, ResponsiveUtils responsive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider mode button
          _buildToggleButton(
            context: context,
            responsive: responsive,
            isSelected: !isLensMode,
            icon: Icons.drag_handle,
            label: context.l10n.dividerLabel,
            onTap: isLensMode ? onToggleMode : null,
          ),
          // Lens mode button
          _buildToggleButton(
            context: context,
            responsive: responsive,
            isSelected: isLensMode,
            icon: Icons.circle_outlined,
            label: context.l10n.lensLabel,
            onTap: !isLensMode ? onToggleMode : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required BuildContext context,
    required ResponsiveUtils responsive,
    required bool isSelected,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? category.color : Colors.white,
              size: responsive.iconSize(20),
            ),
            SizedBox(width: responsive.spacing(4)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? category.color : Colors.white,
                fontSize: responsive.fontSize(28),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
