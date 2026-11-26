import 'package:digipad_flutter/screens/home/home_arch_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const height = 1920.0;
  const count = 7;
  final positions = [
    for (var i = 0; i < count; i++)
      homeArchPosition(index: i, count: count, height: height),
  ];

  test('every card is the same distance from the next one', () {
    final gaps = [
      for (var i = 1; i < count; i++) positions[i].dy - positions[i - 1].dy,
    ];
    for (final gap in gaps) {
      expect(gap, closeTo(gaps.first, 1e-9));
    }
    expect(positions.first.dy, closeTo(height * 0.02, 1e-9));
    expect(positions.last.dy, closeTo(height * 0.72, 1e-9));
  });

  test('arch: symmetric, ends at the edge, middle card at the apex', () {
    for (var i = 0; i < count; i++) {
      expect(positions[i].dx, closeTo(positions[count - 1 - i].dx, 1e-9));
    }
    expect(positions.first.dx, 80);
    expect(positions[count ~/ 2].dx, 20);
  });

  test('curved, not a V: the horizontal step grows towards the ends', () {
    final steps = [
      for (var i = 1; i <= count ~/ 2; i++)
        positions[i - 1].dx - positions[i].dx,
    ];
    // From the top card towards the middle the cards move in less and less.
    expect(steps[0], greaterThan(steps[1]));
    expect(steps[1], greaterThan(steps[2]));
    expect(steps[2], greaterThan(0));
  });
}
