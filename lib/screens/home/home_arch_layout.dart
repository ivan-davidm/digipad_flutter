import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where each home module card goes: `top`/`left` of card [index] out of
/// [count], for a screen [height] tall (MediaQuery height; the caller adds
/// the space kept for the top bar).
///
/// - **Same spacing for every card**: tops are spread evenly from
///   [startFraction] to [endFraction] of the height, so every gap between
///   two cards is identical (client request 2026-11-26).
/// - **A curved arch, not a V**: `left` goes from [edgeLeft] at both ends to
///   [apexLeft] in the middle along `|t|^1.5` (t = -1..1). The old straight
///   steps (75→60→45→30, a V) had a kink at the middle card, which made the
///   cards around it look closer than the rest. Depth went from 45 to 60 px:
///   "a bit more arch, not much" (same request).
Offset homeArchPosition({
  required int index,
  required int count,
  required double height,
  double startFraction = 0.02,
  double endFraction = 0.72,
  double edgeLeft = 80,
  double apexLeft = 20,
}) {
  assert(count > 0 && index >= 0 && index < count);
  if (count == 1) return Offset(apexLeft, height * startFraction);
  final step = (endFraction - startFraction) / (count - 1);
  final top = height * (startFraction + step * index);
  // -1 at the first card, 0 in the middle, 1 at the last one.
  final t = (2 * index / (count - 1)) - 1;
  final left = apexLeft + (edgeLeft - apexLeft) * math.pow(t.abs(), 1.5);
  return Offset(left.toDouble(), top);
}
