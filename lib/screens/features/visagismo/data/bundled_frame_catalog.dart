import 'visagismo_catalog_repository.dart';

/// Frames bundled with the app: 25 real front-view designs (transparent
/// background and lenses) in `assets/images/visagismo/frames/`, cut from the
/// client's "Armazones Reales Transparentes" sheets (5 styles × 5 finishes).
/// The try-on finds each picture's lens centres by itself
/// (`detectFrameLenses`), so adding a frame only needs its PNG and an entry.
///
/// `shapeTags` say which styles a frame has. They are matched against the
/// classifier's `recommendedFrameTags` (ideal / good) and `avoidFrameTags`
/// (not recommended) in `frame_match.dart` — use the exact tags of
/// `face_shape_classifier.dart`. Besides the style mapping agreed with the
/// client (Aviador → ancho_abajo + lente_alto, Cat-eye → cat_eye (fine metal:
/// cat_eye_suave), Cuadrado/Rectangular/Wayfarer → cuadrado/rectangular,
/// Ovalado → ovalado, "grueso vanguardista" → oversize), frames carry the
/// descriptive tags the classifier warns about (anguloso, browline_pesado,
/// bajo, estrecho, rectangular_rigido, redondo_chico) and moderate designs
/// carry casi_cualquier_forma_moderada (the oval face's recommendation).
///
/// TODO(visagismo-real-catalog): once each óptica can upload its own catalog
/// (and this app has a backend to read it from), this becomes one source of
/// `VisagismoCatalogRepository.fetchCatalog()`.
const List<FrameCatalogItem> kBundledFrameCatalog = [
  FrameCatalogItem(
    frameId: 'aviador_ultra_fino_de_metal',
    displayName: 'Aviador ultra-fino de metal',
    detail: 'Alambre dorado clásico',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ancho_abajo', 'lente_alto', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/aviador_ultra_fino_de_metal.png',
  ),
  FrameCatalogItem(
    frameId: 'aviador_de_acetato_clasico',
    displayName: 'Aviador de acetato clásico',
    detail: 'Carey',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ancho_abajo', 'lente_alto', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/aviador_de_acetato_clasico.png',
  ),
  FrameCatalogItem(
    frameId: 'aviador_grueso_vanguardista',
    displayName: 'Aviador grueso vanguardista',
    detail: 'Acetato negro audaz',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ancho_abajo', 'lente_alto', 'oversize'],
    thumbnailUrl: 'assets/images/visagismo/frames/aviador_grueso_vanguardista.png',
  ),
  FrameCatalogItem(
    frameId: 'aviador_translucido_contemporaneo',
    displayName: 'Aviador translúcido contemporáneo',
    detail: 'Acetato champagne',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ancho_abajo', 'lente_alto', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/aviador_translucido_contemporaneo.png',
  ),
  FrameCatalogItem(
    frameId: 'aviador_industrial_moderno',
    displayName: 'Aviador industrial moderno',
    detail: 'Titanio negro mate y mixto',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ancho_abajo', 'lente_alto', 'browline_pesado'],
    thumbnailUrl: 'assets/images/visagismo/frames/aviador_industrial_moderno.png',
  ),
  FrameCatalogItem(
    frameId: 'cat_eye_ultra_fino_de_metal',
    displayName: 'Cat-eye ultra-fino de metal',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cat_eye_suave', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/cat_eye_ultra_fino_de_metal.png',
  ),
  FrameCatalogItem(
    frameId: 'cat_eye_de_acetato_clasico',
    displayName: 'Cat-eye de acetato clásico',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cat_eye', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/cat_eye_de_acetato_clasico.png',
  ),
  FrameCatalogItem(
    frameId: 'cat_eye_grueso_vanguardista',
    displayName: 'Cat-eye grueso vanguardista',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cat_eye', 'oversize'],
    thumbnailUrl: 'assets/images/visagismo/frames/cat_eye_grueso_vanguardista.png',
  ),
  FrameCatalogItem(
    frameId: 'cat_eye_translucido_contemporaneo',
    displayName: 'Cat-eye translúcido contemporáneo',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cat_eye', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/cat_eye_translucido_contemporaneo.png',
  ),
  FrameCatalogItem(
    frameId: 'cat_eye_doble_puente_industrial',
    displayName: 'Cat-eye doble puente industrial',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cat_eye', 'browline_pesado'],
    thumbnailUrl: 'assets/images/visagismo/frames/cat_eye_doble_puente_industrial.png',
  ),
  FrameCatalogItem(
    frameId: 'rectangular_ultra_fino_de_metal',
    displayName: 'Rectangular ultra-fino de metal',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['rectangular', 'anguloso', 'rectangular_rigido', 'bajo', 'estrecho'],
    thumbnailUrl: 'assets/images/visagismo/frames/rectangular_ultra_fino_de_metal.png',
  ),
  FrameCatalogItem(
    frameId: 'cuadrado_de_acetato_clasico',
    displayName: 'Cuadrado de acetato clásico',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'anguloso', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/cuadrado_de_acetato_clasico.png',
  ),
  FrameCatalogItem(
    frameId: 'rectangular_grueso_vanguardista',
    displayName: 'Rectangular grueso vanguardista',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['rectangular', 'oversize', 'anguloso', 'rectangular_rigido'],
    thumbnailUrl: 'assets/images/visagismo/frames/rectangular_grueso_vanguardista.png',
  ),
  FrameCatalogItem(
    frameId: 'cuadrado_translucido_contemporaneo',
    displayName: 'Cuadrado translúcido contemporáneo',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'anguloso', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/cuadrado_translucido_contemporaneo.png',
  ),
  FrameCatalogItem(
    frameId: 'doble_puente_industrial',
    displayName: 'Doble puente industrial',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'rectangular', 'anguloso', 'browline_pesado'],
    thumbnailUrl: 'assets/images/visagismo/frames/doble_puente_industrial.png',
  ),
  FrameCatalogItem(
    frameId: 'ovalado_ultra_fino_de_metal',
    displayName: 'Ovalado ultra-fino de metal',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ovalado', 'redondo', 'circular', 'redondo_chico', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/ovalado_ultra_fino_de_metal.png',
  ),
  FrameCatalogItem(
    frameId: 'ovalado_de_acetato_clasico',
    displayName: 'Ovalado de acetato clásico',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ovalado', 'redondo', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/ovalado_de_acetato_clasico.png',
  ),
  FrameCatalogItem(
    frameId: 'ovalado_grueso_vanguardista',
    displayName: 'Ovalado grueso vanguardista',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ovalado', 'oversize'],
    thumbnailUrl: 'assets/images/visagismo/frames/ovalado_grueso_vanguardista.png',
  ),
  FrameCatalogItem(
    frameId: 'ovalado_translucido_contemporaneo',
    displayName: 'Ovalado translúcido contemporáneo',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ovalado', 'redondo', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/ovalado_translucido_contemporaneo.png',
  ),
  FrameCatalogItem(
    frameId: 'ovalado_doble_puente_industrial',
    displayName: 'Ovalado doble puente industrial',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['ovalado', 'circular', 'browline_pesado'],
    thumbnailUrl: 'assets/images/visagismo/frames/ovalado_doble_puente_industrial.png',
  ),
  FrameCatalogItem(
    frameId: 'wayfarer_ultra_fino_de_metal',
    displayName: 'Wayfarer ultra-fino de metal',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/wayfarer_ultra_fino_de_metal.png',
  ),
  FrameCatalogItem(
    frameId: 'wayfarer_de_acetato_clasico',
    displayName: 'Wayfarer de acetato clásico',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'rectangular', 'anguloso', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/wayfarer_de_acetato_clasico.png',
  ),
  FrameCatalogItem(
    frameId: 'wayfarer_grueso_vanguardista',
    displayName: 'Wayfarer grueso vanguardista',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'rectangular', 'oversize', 'anguloso'],
    thumbnailUrl: 'assets/images/visagismo/frames/wayfarer_grueso_vanguardista.png',
  ),
  FrameCatalogItem(
    frameId: 'wayfarer_translucido_contemporaneo',
    displayName: 'Wayfarer translúcido contemporáneo',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'rectangular', 'anguloso', 'casi_cualquier_forma_moderada'],
    thumbnailUrl: 'assets/images/visagismo/frames/wayfarer_translucido_contemporaneo.png',
  ),
  FrameCatalogItem(
    frameId: 'wayfarer_doble_puente_industrial',
    displayName: 'Wayfarer doble puente industrial',
    brand: 'Genérico',
    tier: 'generic',
    shapeTags: ['cuadrado', 'rectangular', 'browline_pesado'],
    thumbnailUrl: 'assets/images/visagismo/frames/wayfarer_doble_puente_industrial.png',
  ),
];
