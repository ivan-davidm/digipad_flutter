import 'dart:io';

import 'package:digipad_flutter/screens/home/home_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _modules = [
  'virtual_mirror',
  'simulations',
  'lenses_3d',
  'measurements',
  'visagismo',
  'visual_health',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every module has its A, B and C icon in the bundle', () async {
    for (final module in _modules) {
      for (final variant in HomeIconVariant.values) {
        final path = homeIconAsset(module, variant);
        expect(File(path).existsSync(), isTrue, reason: path);
        // Declared in pubspec.yaml (rootBundle only sees declared assets).
        final svg = await rootBundle.loadString(path);
        expect(svg, contains('<svg'), reason: path);
      }
    }
  });

  testWidgets('every variant is drawable by flutter_svg', (tester) async {
    await tester.runAsync(() async {
      for (final module in _modules) {
        for (final variant in HomeIconVariant.values) {
          final path = homeIconAsset(module, variant);
          final info = await vg.loadPicture(SvgAssetLoader(path), null);
          expect(info.size.width, 24, reason: path);
          info.picture.dispose();
        }
      }
    });
  });

  test('the chosen icons are the client choice of 2026-11-26', () {
    expect(kHomeIconChoice, {
      'virtual_mirror': HomeIconVariant.a,
      'simulations': HomeIconVariant.b,
      'lenses_3d': HomeIconVariant.b,
      'measurements': HomeIconVariant.b,
      'visagismo': HomeIconVariant.c,
      'visual_health': HomeIconVariant.b,
    });
  });
}
