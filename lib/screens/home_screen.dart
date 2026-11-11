import 'dart:ui';
import 'package:digipad_flutter/common/components/d_image.dart';
import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_cubit.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/presentation/lenses_3d_screen.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/totem_cubit.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/totem_state.dart';
import 'package:digipad_flutter/features/photo_sync/presentation/photo_sync_role_screen.dart';
import 'package:digipad_flutter/screens/features/simulations/presentation/main_simulations_grid_screen.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/cubit/virtual_mirror_cubit.dart';
import 'package:digipad_flutter/screens/features/virtual_mirror/presentation/virtual_mirror_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/measurement_hub_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/shared_image_intent_handler.dart';
import 'package:digipad_flutter/screens/features/visual_health/cubit/visual_health_cubit.dart';
import 'package:digipad_flutter/screens/features/visual_health/presentation/visual_health_screen.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/presentation/visagismo_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:digipad_flutter/main.dart';
import 'package:digipad_flutter/digi_locale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Session-scoped TOTEM cubit ──────────────────────────────────────────────
  late final TotemCubit _hostCubit;
  late final GalleryStorage _galleryStorage;

  // ── Entrance animation ──────────────────────────────────────────────────────
  late final AnimationController _entranceController;
  static const int _moduleCount = 7;

  // Lets a photo shared into DigiTower from another app (e.g. WhatsApp) open
  // straight in the measurement editor — started here, not in main.dart,
  // since reaching this screen already means activation passed.
  late final SharedImageIntentHandler _sharedImageIntentHandler;

  @override
  void initState() {
    super.initState();

    _galleryStorage = GalleryStorage();
    _hostCubit = TotemCubit(storage: _galleryStorage);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _sharedImageIntentHandler = SharedImageIntentHandler(rootNavigatorKey)
      ..start();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _hostCubit.close();
    _sharedImageIntentHandler.dispose();
    super.dispose();
  }

  // ── Module definitions (order = visual top-to-bottom) ──────────────────────
  List<_ModuleDef> _modules(BuildContext context) => [
    _ModuleDef(
      key: 'virtual_mirror',
      title: context.l10n.menuVirtualMirror,
      icon: Icons.face_retouching_natural,
      color: Colors.white,
      top: MediaQuery.of(context).size.height * 0.02,
      left: 75,
    ),
    _ModuleDef(
      key: 'simulations',
      title: context.l10n.menuSimulations,
      icon: Icons.auto_fix_high,
      color: const Color(0xFF4CAF50),
      top: MediaQuery.of(context).size.height * 0.12,
      left: 60,
    ),
    _ModuleDef(
      key: 'lenses_3d',
      title: context.l10n.menuLenses3D,
      icon: Icons.view_in_ar,
      color: Colors.white,
      top: MediaQuery.of(context).size.height * 0.25,
      left: 45,
    ),
    // 'cosmetic_lenses' hidden per product decision (2026-11-05) — not
    // deleted, just no longer in this list. To bring it back: re-add its
    // _ModuleDef (icon: Icons.remove_red_eye_outlined, color: 0xFF2196F3,
    // key/title: menuCosmeticLenses) and its `_navigateToModule` branch
    // (CosmeticLensesCubit/CosmeticLensesScreen), bump `_moduleCount` back to
    // 8, and re-tune every module's `top` fraction for 8 slots again.
    _ModuleDef(
      key: 'measurements',
      title: context.l10n.menuMeasurements,
      icon: Icons.straighten,
      color: const Color(0xFFFB8C00),
      top: MediaQuery.of(context).size.height * 0.37,
      left: 30,
    ),
    _ModuleDef(
      key: 'visagismo',
      title: context.l10n.menuVisagismo,
      icon: Icons.face,
      color: const Color(0xFF9C27B0),
      top: MediaQuery.of(context).size.height * 0.49,
      left: 45,
    ),
    _ModuleDef(
      key: 'visual_health',
      title: context.l10n.menuVisualHealth,
      icon: Icons.health_and_safety_outlined,
      color: const Color(0xFFFFD600),
      top: MediaQuery.of(context).size.height * 0.60,
      left: 60,
    ),
    _ModuleDef(
      key: 'photo_sync',
      title: context.l10n.menuPhotoSync,
      icon: Icons.sync_alt_rounded,
      color: const Color(0xFF00BFA6),
      top: MediaQuery.of(context).size.height * 0.72,
      left: 75,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final modules = _modules(context);

    return BlocProvider.value(
      value: _hostCubit,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: DImage(imageName: 'background').provider,
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // ── Staggered module cards ────────────────────────────────────
                for (int i = 0; i < modules.length; i++)
                  Positioned(
                    top: modules[i].top,
                    left: modules[i].left,
                    child: _AnimatedModuleItem(
                      index: i,
                      total: _moduleCount,
                      controller: _entranceController,
                      child: _buildArchMenuItem(
                        context: context,
                        def: modules[i],
                        onTap: () => _navigateToModule(context, modules[i].key),
                      ),
                    ),
                  ),

                // ── Language picker ───────────────────────────────────────────
                Positioned(
                  top: 8,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LanguageCodeType>(
                        dropdownColor: Colors.grey.shade900,
                        iconEnabledColor: Colors.white,
                        value: LanguageCodeType.values.firstWhere(
                          (e) =>
                              e.name ==
                              Localizations.localeOf(context).languageCode,
                          orElse: () => LanguageCodeType.en,
                        ),
                        items: LanguageCodeType.values.map((e) {
                          final code = e.name;
                          final label = code == 'en'
                              ? context.l10n.languageEnglish
                              : code == 'es'
                              ? context.l10n.languageSpanish
                              : context.l10n.languagePortuguese;
                          return DropdownMenuItem(
                            value: e,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: MediaQuery.of(context).size.shortestSide >= 550 ? 16.0 : 11.0,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          MyApp.setLocale(context, Locale(val.name));
                        },
                      ),
                    ),
                  ),
                ),

                // ── TOTEM active badge (top-left, below language picker) ──────
                Positioned(
                  top: 8,
                  left: 12,
                  child: BlocBuilder<TotemCubit, TotemState>(
                    bloc: _hostCubit,
                    builder: (context, state) {
                      if (state is! TotemActive) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () => _navigateToModule(context, 'photo_sync'),
                        child: _TotemActiveBadge(imageCount: state.photoCount),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Individual pill button ────────────────────────────────────────────────

  Widget _buildArchMenuItem({
    required BuildContext context,
    required _ModuleDef def,
    required VoidCallback onTap,
  }) {
    final size = MediaQuery.of(context).size;
    final buttonWidth = size.width * 0.4;
    final buttonHeight = size.height * 0.06;
    final isTablet = size.shortestSide >= 550;
    final iconSize = isTablet ? 30.0 : 16.0;
    final labelFontSize = isTablet ? 20.0 : 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: buttonWidth,
            height: buttonHeight,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: def.color.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Icon(def.icon, color: def.color, size: iconSize),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    def.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black87,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateToModule(BuildContext context, String moduleId) {
    if (moduleId == 'virtual_mirror') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => VirtualMirrorCubit(GalleryStorage()..init()),
            child: const VirtualMirrorScreen(),
          ),
        ),
      );
    } else if (moduleId == 'simulations') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MainSimulationsGridScreen(),
        ),
      );
    } else if (moduleId == 'measurements') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MeasurementHubScreen()),
      );
    } else if (moduleId == 'lenses_3d') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => Lenses3DCubit(),
            child: const Lenses3DScreen(),
          ),
        ),
      );
    } else if (moduleId == 'visagismo') {
      // This app already runs AS the Tótem (see the "TÓTEM activa" badge
      // above) — Visagismo captures save straight to this app's own
      // internal gallery (see VisagismoResultScreen), no pairing needed.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => VisagismoCubit(),
            child: const VisagismoEntryScreen(),
          ),
        ),
      );
    } else if (moduleId == 'visual_health') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => VisualHealthCubit(),
            child: const VisualHealthScreen(),
          ),
        ),
      );
    } else if (moduleId == 'photo_sync') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: _hostCubit,
            child: const PhotoSyncRoleScreen(),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2c2c2c),
            title: const Text('Info', style: TextStyle(color: Colors.white)),
            content: Text(
              context.l10n.dialogNavigatingContent(moduleId),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.ok,
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          );
        },
      );
    }
  }
}

// ── Helper data class ──────────────────────────────────────────────────────────

class _ModuleDef {
  final String key;
  final String title;
  final IconData icon;
  final Color color;
  final double top;
  final double left;

  const _ModuleDef({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.top,
    required this.left,
  });
}

// ── Staggered entrance widget ─────────────────────────────────────────────────

class _AnimatedModuleItem extends StatelessWidget {
  final int index;
  final int total;
  final AnimationController controller;
  final Widget child;

  const _AnimatedModuleItem({
    required this.index,
    required this.total,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Each card starts 80 ms later than the previous one.
    final stagger = index / total;
    final start = stagger * 0.55;
    final end = (start + 0.45).clamp(0.0, 1.0);

    final slide = Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          ),
        );

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: Curves.easeIn),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}

// ── TOTEM active badge ────────────────────────────────────────────────────────

class _TotemActiveBadge extends StatelessWidget {
  final int imageCount;
  const _TotemActiveBadge({required this.imageCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFA6).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5EFCE8), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA6).withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_tethering_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'TÓTEM · $imageCount 📷',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
