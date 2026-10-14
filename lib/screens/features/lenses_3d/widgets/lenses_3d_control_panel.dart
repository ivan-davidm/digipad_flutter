import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_cubit.dart';
import 'package:digipad_flutter/screens/features/lenses_3d/cubit/lenses_3d_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

class Lenses3DControlPanel extends StatelessWidget {
  final String label;

  const Lenses3DControlPanel({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<Lenses3DCubit>();

    return BlocBuilder<Lenses3DCubit, Lenses3DState>(
      builder: (context, state) {
        final isSinGlasses = state.prescription == 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Material row: [Sin Lentes] [1.50] [1.60] [1.70] [1.80]
              _buildMaterialSelector(context, state, cubit, isSinGlasses),

              // Frame + Prescription: only when a real material is selected
              if (!isSinGlasses) ...[
                const SizedBox(height: 4),
                _buildFrameSelector(context, state, cubit),
                const SizedBox(height: 4),
                _buildPrescriptionControl(context, state, cubit),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialSelector(
    BuildContext context,
    Lenses3DState state,
    Lenses3DCubit cubit,
    bool isSinGlasses,
  ) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        // Sin Lentes chip
        _Chip(
          label: context.l10n.sinGlasses,
          selected: isSinGlasses,
          color: Colors.greenAccent.shade700,
          onTap: cubit.selectSinGlasses,
        ),
        // Material index chips
        ...LensMaterialIndex.values.map((material) => _Chip(
          label: material.displayName,
          selected: !isSinGlasses && state.materialIndex == material,
          color: Colors.blueAccent,
          onTap: () => cubit.updateMaterialIndex(material),
        )),
      ],
    );
  }

  Widget _buildFrameSelector(
    BuildContext context,
    Lenses3DState state,
    Lenses3DCubit cubit,
  ) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: LensFrameType.values.map((frame) => _Chip(
        label: frame.displayName,
        selected: state.frameType == frame,
        color: Colors.blueAccent,
        onTap: () => cubit.updateFrameType(frame),
      )).toList(),
    );
  }

  Widget _buildPrescriptionControl(
    BuildContext context,
    Lenses3DState state,
    Lenses3DCubit cubit,
  ) {
    return Row(
      children: [
        Text(
          context.l10n.prescription,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${state.prescription}D',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: state.prescription > state.minPrescription
              ? cubit.decrementPrescription
              : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.blueAccent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          iconSize: 16,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: Colors.blueAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              trackHeight: 2,
            ),
            child: Slider(
              value: state.prescription.toDouble(),
              min: state.minPrescription.toDouble(),
              max: state.maxPrescription.toDouble(),
              divisions: state.maxPrescription - state.minPrescription,
              onChanged: (v) => cubit.updatePrescription(v.round()),
            ),
          ),
        ),
        IconButton(
          onPressed: state.prescription < state.maxPrescription
              ? cubit.incrementPrescription
              : null,
          icon: const Icon(Icons.add_circle_outline),
          color: Colors.blueAccent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          iconSize: 16,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.8) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
