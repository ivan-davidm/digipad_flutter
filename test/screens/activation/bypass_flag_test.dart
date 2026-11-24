import 'package:digipad_flutter/screens/activation/cubit/activation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Guard: a build made without `--dart-define=BYPASS_ACTIVATION=true` (every
  // release build) must keep the activation gate. If this fails, somebody
  // hardcoded the bypass back to `true`.
  test('activation bypass is off unless explicitly requested', () {
    expect(ActivationCubit.kBypassActivation, isFalse);
  });
}
