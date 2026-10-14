import 'package:auto_size_text/auto_size_text.dart';
import 'package:digipad_flutter/common/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

import '../cubit/simulations_cubit.dart';
import '../cubit/simulations_state.dart';
import '../data/simulation_data.dart';
import '../models/simulation_scenario.dart';
import 'simulation_viewer_screen.dart';
import 'simulation_strings.dart';

/// Main grid screen for selecting visual problems and scenarios.
class MainSimulationsGridScreen extends StatelessWidget {
  const MainSimulationsGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SimulationsCubit(),
      child: const _SimulationsGridView(),
    );
  }
}

class _SimulationsGridView extends StatelessWidget {
  const _SimulationsGridView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimulationsCubit, SimulationsState>(
      builder: (context, state) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, state),
              if (state.selectedCategory == null)
                _buildCategoryGrid(context)
              else
                _buildScenarioGrid(context, state.selectedCategory!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, SimulationsState state) {
    final theme = Theme.of(context);
    final isPhone = MediaQuery.of(context).size.width < 600;

    final title = state.selectedCategory == null
        ? context.l10n.lensSimulatorTitle
        : SimulationStrings.categoryName(context, state.selectedCategory!);

    final description = state.selectedCategory != null
        ? SimulationStrings.categoryDescription(
            context,
            state.selectedCategory!,
          )
        : null;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.primaryColor,
      toolbarHeight: isPhone ? 48 : 64,
      expandedHeight: description != null ? (isPhone ? 88 : 120) : (isPhone ? 68 : 100),
      leadingWidth: isPhone ? 52 : 72,
      leading: Center(
        child: SizedBox(
          width: isPhone ? 36 : 48,
          height: isPhone ? 20 : 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: isPhone ? 20 : 28,
              color: Colors.white,
            ),
            onPressed: () {
              if (state.selectedCategory != null) {
                context.read<SimulationsCubit>().goToCategories();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),

      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha: 0.7),
              Colors.deepPurple.shade700,
            ],
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(isPhone ? 52 : 72, 0, isPhone ? 16 : 32, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isPhone ? 20 : 32,
                    color: Colors.white,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isPhone ? 13 : 20,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final allCategories = SimulationData.categories;
    final visionProblems = ['myopia', 'presbyopia'];
    final lensTypes = ['monofocal', 'bifocal', 'multifocal'];

    final treatmentCategories = allCategories
        .where(
          (c) => !visionProblems.contains(c.id) && !lensTypes.contains(c.id),
        )
        .toList();
    final typeCategories = allCategories
        .where((c) => lensTypes.contains(c.id))
        .toList();
    final problemCategories = allCategories
        .where((c) => visionProblems.contains(c.id))
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionHeader(context.l10n.lensTreatments),
        _buildGridSection(context, treatmentCategories),
        const SizedBox(height: 24),
        _buildSectionHeader(context.l10n.lensType),
        _buildGridSection(context, typeCategories),
        const SizedBox(height: 24),
        _buildSectionHeader(context.l10n.refractiveConditions),
        _buildGridSection(context, problemCategories),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OrientationBuilder(
          builder: (context, orientation) {
            final responsive = context.responsive(constraints, orientation);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: responsive.fontSize(24),
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridSection(
    BuildContext context,
    List<SimulationCategory> categories,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isPhone ? 2 : 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: isPhone ? 12 : 16,
        mainAxisSpacing: isPhone ? 12 : 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onTap: () {
            context.read<SimulationsCubit>().selectCategory(category);
          },
        );
      },
    );
  }

  Widget _buildScenarioGrid(BuildContext context, SimulationCategory category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isPhone ? 1 : 2,
          childAspectRatio: isPhone ? 1.2 : 0.75,
          crossAxisSpacing: isPhone ? 12 : 16,
          mainAxisSpacing: isPhone ? 12 : 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final scenario = category.scenarios[index];
          return _ScenarioCard(
            scenario: scenario,
            category: category,
            onTap: () => _navigateToViewer(context, category, scenario),
          );
        }, childCount: category.scenarios.length),
      ),
    );
  }

  void _navigateToViewer(
    BuildContext context,
    SimulationCategory category,
    SimulationScenario scenario,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SimulationViewerScreen(category: category, scenario: scenario),
      ),
    );
  }
}

/// Card widget for displaying a category.
class _CategoryCard extends StatelessWidget {
  final SimulationCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  IconData get _icon => category.icon;
  Color get _iconColor => category.color;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _iconColor.withValues(alpha: 0.1)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    size: isPhone ? 32 : 90,
                    color: _iconColor,
                  ),
                ),
                const SizedBox(height: 12),
                AutoSizeText(
                  SimulationStrings.categoryName(context, category),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isPhone ? 16 : 40,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  minFontSize: 10,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.scenesCount(category.scenarios.length),
                  style: TextStyle(
                    fontSize: isPhone ? 11 : 22,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card widget for displaying a scenario with preview.
class _ScenarioCard extends StatelessWidget {
  final SimulationScenario scenario;
  final SimulationCategory category;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    scenario.problemImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.withoutLens,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AutoSizeText(
                      SimulationStrings.scenarioName(context, scenario),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isPhone ? 14 : 28,
                      ),
                      maxLines: 1,
                      minFontSize: 10,
                    ),
                    if (scenario.correctionLenses.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.lensesAvailable(
                          scenario.correctionLenses.length,
                        ),
                        style: TextStyle(
                          fontSize: isPhone ? 12 : 22,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: isPhone ? 32 : 48,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: scenario.correctionLenses
                                .map(
                                  (lens) => Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLensColor(
                                        lens.quality,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: AutoSizeText(
                                      SimulationStrings.lensName(
                                        context,
                                        lens,
                                      ),
                                      style: TextStyle(
                                        fontSize: isPhone ? 13 : 28,
                                        color: _getLensColor(lens.quality),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      minFontSize: 9,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLensColor(LensQuality quality) {
    switch (quality) {
      case LensQuality.economy:
        return Colors.grey.shade600;
      case LensQuality.standard:
        return Colors.blue;
      case LensQuality.good:
        return Colors.green;
      case LensQuality.premium:
        return Colors.amber.shade700;
    }
  }
}
