import 'package:digipad_flutter/common/utils/responsive_utils.dart';
import 'package:digipad_flutter/screens/features/visual_health/cubit/visual_health_cubit.dart';
import 'package:digipad_flutter/screens/features/visual_health/cubit/visual_health_state.dart';
import 'package:digipad_flutter/screens/features/visual_health/widgets/test_display_widget.dart';
import 'package:digipad_flutter/screens/features/visual_health/widgets/test_gallery_widget.dart';
import 'package:digipad_flutter/screens/features/visual_health/widgets/visual_health_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

class VisualHealthScreen extends StatefulWidget {
  const VisualHealthScreen({super.key});

  @override
  State<VisualHealthScreen> createState() => _VisualHealthScreenState();
}

class _VisualHealthScreenState extends State<VisualHealthScreen> {
  @override
  void initState() {
    super.initState();
    context.read<VisualHealthCubit>().initTests();
  }

  String _categoryLabel(BuildContext context, VisualHealthCategory cat) {
    switch (cat) {
      case VisualHealthCategory.visionTests:
        return context.l10n.vhCatVisionTests;
      case VisualHealthCategory.ishihara:
        return context.l10n.vhCatIshihara;
      case VisualHealthCategory.childrenBicromatic:
        return context.l10n.vhCatChildrenTest;
      case VisualHealthCategory.ametropia:
        return context.l10n.vhCatAmetropia;
      case VisualHealthCategory.pathologies:
        return context.l10n.vhCatPathologies;
      case VisualHealthCategory.amsler:
        return context.l10n.vhCatAmsler;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return OrientationBuilder(
              builder: (context, orientation) {
                final responsive = context.responsive(constraints, orientation);

                return Column(
                  children: [
                    BlocBuilder<VisualHealthCubit, VisualHealthState>(
                      builder: (context, state) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Category dropdown
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade600),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<VisualHealthCategory>(
                                      value: state.selectedCategory,
                                      dropdownColor: Colors.grey.shade800,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: responsive.fontSize(16),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white70),
                                      isExpanded: true,
                                      items: VisualHealthCategory.values
                                          .map((cat) =>
                                              DropdownMenuItem(
                                                value: cat,
                                                child: Text(
                                                    _categoryLabel(
                                                        context, cat)),
                                              ))
                                          .toList(),
                                      onChanged: (cat) {
                                        if (cat != null) {
                                          context
                                              .read<VisualHealthCubit>()
                                              .selectCategory(cat);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Test counter
                              if (state.isInitialized &&
                                  state.testImages.isNotEmpty)
                                Text(
                                  context.l10n.vhTestSummary(
                                    state.currentTestIndex + 1,
                                    state.testImages.length,
                                  ),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: responsive.fontSize(14),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Expanded(child: TestDisplayWidget()),
                    const TestGalleryWidget(),
                    const VisualHealthControlPanel(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
