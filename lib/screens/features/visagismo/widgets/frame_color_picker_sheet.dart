import 'package:flutter/material.dart';

/// A named frame color swatch shown in the picker.
class FrameColorOption {
  const FrameColorOption(this.label, this.color);

  final String label;
  final Color color;
}

// Placeholder recommendation sets — these need to be calibrated against the
// client's own colorimetry reference doc (skin-tone/frame-color pairing)
// once it's available; nothing here is pulled from that doc yet.
const List<FrameColorOption> _kLightSkinRecommended = [
  FrameColorOption('Negro', Color(0xFF1A1A1A)),
  FrameColorOption('Azul marino', Color(0xFF1E3A5F)),
  FrameColorOption('Carey clásico', Color(0xFF8B5A2B)),
  FrameColorOption('Borgoña', Color(0xFF6D1F36)),
  FrameColorOption('Gris grafito', Color(0xFF4A4A4A)),
  FrameColorOption('Verde botella', Color(0xFF1F4D3A)),
];

const List<FrameColorOption> _kGeneralPalette = [
  FrameColorOption('Negro', Color(0xFF1A1A1A)),
  FrameColorOption('Blanco', Color(0xFFF5F5F5)),
  FrameColorOption('Carey', Color(0xFF8B5A2B)),
  FrameColorOption('Azul', Color(0xFF2E5EAA)),
  FrameColorOption('Celeste', Color(0xFF4FC3F7)),
  FrameColorOption('Rojo', Color(0xFFC62828)),
  FrameColorOption('Rosa', Color(0xFFD8759A)),
  FrameColorOption('Verde', Color(0xFF2E7D4F)),
  FrameColorOption('Violeta', Color(0xFF6A4C93)),
  FrameColorOption('Dorado', Color(0xFFC9A24B)),
  FrameColorOption('Plateado', Color(0xFFB0B5BA)),
  FrameColorOption('Transparente', Color(0xFFE0E0D8)),
];

const List<FrameColorOption> _kDarkSkinRecommended = [
  FrameColorOption('Dorado', Color(0xFFC9A24B)),
  FrameColorOption('Carey cálido', Color(0xFFA9662E)),
  FrameColorOption('Rojo intenso', Color(0xFFB7281E)),
  FrameColorOption('Blanco', Color(0xFFF5F5F5)),
  FrameColorOption('Verde esmeralda', Color(0xFF1C8A5C)),
  FrameColorOption('Cobre', Color(0xFFB5651D)),
];

/// Bottom sheet shown after picking a frame: lets the client choose a frame
/// color, grouped into tones recommended for lighter skin, a free-form
/// palette, and tones recommended for darker skin.
class FrameColorPickerSheet extends StatefulWidget {
  const FrameColorPickerSheet({
    super.key,
    required this.frameName,
    this.onColorSelected,
  });

  final String frameName;
  final ValueChanged<FrameColorOption>? onColorSelected;

  static Future<FrameColorOption?> show(
    BuildContext context, {
    required String frameName,
  }) {
    return showModalBottomSheet<FrameColorOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FrameColorPickerSheet(frameName: frameName),
    );
  }

  @override
  State<FrameColorPickerSheet> createState() => _FrameColorPickerSheetState();
}

class _FrameColorPickerSheetState extends State<FrameColorPickerSheet> {
  FrameColorOption? _selected;

  void _select(FrameColorOption option) {
    setState(() => _selected = option);
    widget.onColorSelected?.call(option);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF17171C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Color de marco',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.frameName,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 22),
              _ColorSection(
                title: 'Recomendado para pieles claras',
                icon: Icons.light_mode_outlined,
                accent: const Color(0xFFE8C07D),
                options: _kLightSkinRecommended,
                selected: _selected,
                onTap: _select,
              ),
              const SizedBox(height: 22),
              _ColorSection(
                title: 'Paleta de colores',
                icon: Icons.palette_outlined,
                accent: Colors.deepPurpleAccent,
                options: _kGeneralPalette,
                selected: _selected,
                onTap: _select,
              ),
              const SizedBox(height: 22),
              _ColorSection(
                title: 'Recomendado para pieles oscuras',
                icon: Icons.dark_mode_outlined,
                accent: const Color(0xFF8B5A2B),
                options: _kDarkSkinRecommended,
                selected: _selected,
                onTap: _select,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selected == null
                        ? 'Elegí un color'
                        : 'Confirmar ${_selected!.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColorSection extends StatelessWidget {
  const _ColorSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<FrameColorOption> options;
  final FrameColorOption? selected;
  final ValueChanged<FrameColorOption> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: options.map((option) {
            final isSelected = selected?.label == option.label;
            return GestureDetector(
              onTap: () => onTap(option),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: _contrastingIconColor(option.color),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 60,
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Color _contrastingIconColor(Color background) {
  return background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
