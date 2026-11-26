import 'dart:io';

import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The camera-less flow (DigiTower 3D Premium on the Tótem): no camera
/// permission, photo picked from a gallery, and "Repetir" never deletes it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No ML Kit in unit tests: detection gets no answer (reported as a
  // detector failure, never as "no face") and closing it is a no-op.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('google_mlkit_face_detector'),
          (_) async => null,
        );
  });

  test('without camera it goes straight to the photo picker', () async {
    final cubit = VisagismoCubit(cameraEnabled: false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.step, VisagismoStep.capture);
    expect(cubit.state.cameraPermissionDenied, isFalse);
    await cubit.close();
  });

  test('a picked photo is scanned and is not deleted on retake', () async {
    final dir = await Directory.systemTemp.createTemp('visagismo_test');
    final photo = File('${dir.path}/client.jpg')..writeAsBytesSync([0, 1, 2]);
    final cubit = VisagismoCubit(cameraEnabled: false);
    await Future<void>.delayed(Duration.zero);

    final scan = cubit.onPhotoPicked(photo.path);
    expect(cubit.state.step, VisagismoStep.scanning);
    expect(cubit.state.capturedImagePath, photo.path);
    expect(cubit.state.capturedFromCamera, isFalse);
    await scan;
    expect(cubit.state.step, VisagismoStep.result);

    cubit.retakePhoto();
    expect(cubit.state.step, VisagismoStep.capture);
    expect(cubit.state.capturedImagePath, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(photo.existsSync(), isTrue);

    await cubit.close();
    await dir.delete(recursive: true);
  });
}
