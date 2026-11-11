import 'package:digipad_flutter/common/utils/responsive_utils.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/cubit/virtual_mirror_cubit.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/cubit/virtual_mirror_state.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/widgets/control_panel.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/widgets/gallery_section.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/widgets/image_dropzone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VirtualMirrorScreen extends StatefulWidget {
  const VirtualMirrorScreen({super.key});

  @override
  State<VirtualMirrorScreen> createState() => _VirtualMirrorScreenState();
}

class _VirtualMirrorScreenState extends State<VirtualMirrorScreen> {
  @override
  void initState() {
    super.initState();
    context.read<VirtualMirrorCubit>().initGallery();
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
                    // Title
                    Padding(
                      padding: responsive.padding(
                        const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        context.l10n.vmDragAndDrop,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: responsive.fontSize(38),
                        ),
                      ),
                    ),

                    // Image comparison area - horizontal on tablets, vertical on phones
                    Expanded(
                      child: responsive.shouldUseSideBySideLayout
                          ? Row(
                              children: [
                                const Expanded(
                                  child: ImageDropZone(
                                    side: DropSide.left,
                                    showEmptyMessage: true,
                                  ),
                                ),
                                VerticalDivider(
                                  indent: responsive.spacing(20),
                                  endIndent: responsive.spacing(20),
                                  width: 8,
                                  color: Colors.grey.shade400,
                                  thickness: 3,
                                ),
                                const Expanded(
                                  child: ImageDropZone(
                                    side: DropSide.right,
                                    showEmptyMessage: true,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const Expanded(
                                  child: ImageDropZone(
                                    side: DropSide.left,
                                    showEmptyMessage: true,
                                  ),
                                ),
                                Divider(
                                  indent: responsive.spacing(20),
                                  endIndent: responsive.spacing(20),
                                  height: 8,
                                  color: Colors.grey.shade400,
                                  thickness: 3,
                                ),
                                const Expanded(
                                  child: ImageDropZone(
                                    side: DropSide.right,
                                    showEmptyMessage: true,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // Gallery section
                    BlocBuilder<VirtualMirrorCubit, VirtualMirrorState>(
                      builder: (context, state) {
                        if (state.galleryImages.isEmpty) {
                          return Padding(
                            padding: responsive.padding(
                              const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Card(
                              color: Colors.grey.shade900,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  responsive.borderRadius(16),
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade600,
                                  width: 1,
                                ),
                              ),
                              child: SizedBox(
                                height: responsive.isPhone ? 150 : 250,
                                child: Center(
                                  child: Text(
                                    textAlign: TextAlign.center,
                                    context.l10n.vmNoImages,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: responsive.fontSize(24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return GallerySection(gallery: state.galleryImages);
                      },
                    ),
                    // Control panel
                    const ControlPanel(),
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

enum DropSide { left, right }
