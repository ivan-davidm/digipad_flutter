import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The home module icons: drawn from scratch, white, three variants each
/// (`assets/svgs/home_icons/<module key>_<a|b|c>.svg`). All variants ship
/// with the app so the choice can change without new artwork.
///
/// | Module | A | B | C |
/// |---|---|---|---|
/// | virtual_mirror | mirror with sparkles | mirror on a stand | reflection lines |
/// | simulations | progressive + gradient lens | round, striped gradient | filled corridor |
/// | lenses_3d | half lens (profile) | thick vs thin profiles | cut dome |
/// | measurements | face, glasses, 4-dot bar | 4 corner markers | bar + PD line |
/// | visagismo | face, outward arrows | scanner corners | height/width arrows |
/// | visual_health | stroked cross | solid cross, square lenses | filled lens |
enum HomeIconVariant { a, b, c }

/// Variant shown for each module (client's choice, 2026-11-26). Change a
/// letter here to swap an icon. Modules not listed keep their Material icon.
const Map<String, HomeIconVariant> kHomeIconChoice = {
  'virtual_mirror': HomeIconVariant.a,
  'simulations': HomeIconVariant.b,
  'lenses_3d': HomeIconVariant.b,
  'measurements': HomeIconVariant.b,
  'visagismo': HomeIconVariant.c,
  'visual_health': HomeIconVariant.b,
};

/// Asset path of [variant] of [moduleKey]'s icon.
String homeIconAsset(String moduleKey, HomeIconVariant variant) =>
    'assets/svgs/home_icons/${moduleKey}_${variant.name}.svg';

/// [moduleKey]'s chosen icon at [size], or null when it has none.
Widget? homeModuleIcon(String moduleKey, double size) {
  final variant = kHomeIconChoice[moduleKey];
  if (variant == null) return null;
  return SvgPicture.asset(
    homeIconAsset(moduleKey, variant),
    width: size,
    height: size,
  );
}
