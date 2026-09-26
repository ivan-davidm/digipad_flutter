import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:digipad_flutter/screens/activation/data/activation_service.dart';

part 'activation_state.dart';

class ActivationCubit extends Cubit<ActivationState> {
  final ActivationService _service;
  StreamSubscription? _subscription;

  DateTime? _lastOnlineAccessUpdate;
  static const int _accessUpdateThrottleMinutes = 5;

  // ─── DEV FLAGS ───────────────────────────────────────────────────────────
  // Set to true to skip all activation checks (local testing only).
  static const bool kBypassActivation = false;
  // ─────────────────────────────────────────────────────────────────────────

  ActivationCubit(this._service) : super(const ActivationState());

  Future<void> init() async {
    if (kBypassActivation) {
      emit(
        state.copyWith(status: ActivationStatus.approved, email: 'dev@bypass'),
      );
      return;
    }
    await _subscription?.cancel();
    emit(state.copyWith(status: ActivationStatus.checking));

    final savedEmail = await _service.getSavedEmail();
    final hasInternet = await _service.checkInternetConnection();

    if (!hasInternet) {
      if (savedEmail == null) {
        emit(state.copyWith(status: ActivationStatus.notRegistered));
        return;
      }

      // Lifetime activation: once a device has been approved it works offline
      // permanently — no interaction counter, no expiry.
      final isLocallyApproved = await _service.isLocallyApproved();
      if (isLocallyApproved) {
        emit(state.copyWith(status: ActivationStatus.approved, email: savedEmail));
        return;
      }

      // Not yet approved: internet is required to verify.
      emit(state.copyWith(status: ActivationStatus.error, errorMessage: 'activationNoInternet'));
      return;
    }

    if (savedEmail == null) {
      emit(state.copyWith(status: ActivationStatus.notRegistered));
      return;
    }

    await _service.updateLastAccess(savedEmail);
    _lastOnlineAccessUpdate = DateTime.now();

    try {
      final stream = _service.getActivationStream(savedEmail);
      _subscription = stream.listen(
        (snapshot) async {
          if (snapshot == null || !snapshot.exists) {
            if (state.status != ActivationStatus.checking &&
                state.status != ActivationStatus.pendingApproval) {
              await _service.clearSavedEmail();
              await _service.setLocallyApproved(false);
              emit(state.copyWith(status: ActivationStatus.notRegistered));
            }
          } else {
            final data = snapshot.data();
            final isApproved = data?['isApproved'] == true;
            final email = data?['email'] as String? ?? savedEmail;

            if (isApproved) {
              await _service.setLocallyApproved(true);
              await _service.resetOfflineInteractions();
              emit(
                state.copyWith(status: ActivationStatus.approved, email: email),
              );
            } else {
              await _service.setLocallyApproved(false);
              emit(
                state.copyWith(
                  status: ActivationStatus.pendingApproval,
                  email: email,
                ),
              );
            }
          }
        },
        onError: (e) {
          emit(
            state.copyWith(
              status: ActivationStatus.error,
              errorMessage: 'Error checking activation: $e',
            ),
          );
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ActivationStatus.error,
          errorMessage: 'Failed to start activation listener: $e',
        ),
      );
    }
  }

  Future<void> handleInteraction() async {
    final hasInternet = await _service.checkInternetConnection();

    if (!hasInternet) {
      // Lifetime activation: locally approved devices always have offline access.
      final isLocallyApproved = await _service.isLocallyApproved();
      if (isLocallyApproved) return;

      // Not approved + no internet → block immediately.
      if (state.status != ActivationStatus.blockedOffline) {
        emit(state.copyWith(status: ActivationStatus.blockedOffline, errorMessage: null));
      }
    } else {
      if (state.status == ActivationStatus.notRegistered) return;

      final now = DateTime.now();

      if (_lastOnlineAccessUpdate == null ||
          now.difference(_lastOnlineAccessUpdate!).inMinutes >=
              _accessUpdateThrottleMinutes) {
        _lastOnlineAccessUpdate = now;

        final savedEmail = await _service.getSavedEmail();
        if (savedEmail != null) {
          _service.updateLastAccess(savedEmail);
        }
      }
    }
  }

  Future<void> submitRequest(String email) async {
    if (email.isEmpty) return;

    final hasInternet = await _service.checkInternetConnection();
    if (!hasInternet) {
      emit(
        state.copyWith(
          status: ActivationStatus.error,
          errorMessage: 'activationNoInternet',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ActivationStatus.checking));
    try {
      await _service
          .requestActivation(email)
          .timeout(const Duration(seconds: 30));

      await _service.saveEmail(email);
      await init();
    } catch (e) {
      String msg = 'activationErrorTitle';

      if (e is TimeoutException) {
        msg = 'activationConnectionTimeout';
      } else if (e.toString().contains('email_already_used')) {
        emit(
          state.copyWith(
            status: ActivationStatus.pendingApproval,
            email: email,
            errorMessage: 'activationRequestExists',
          ),
        );
        return;
      } else if (e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('UnknownHostException')) {
        msg = 'activationConnectionRequired';
      }

      emit(
        state.copyWith(
          status: ActivationStatus.error,
          errorMessage: msg,
          email: email, // Preserve email for retry
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
