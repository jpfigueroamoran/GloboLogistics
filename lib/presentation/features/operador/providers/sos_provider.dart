import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/usecases/seguridad/trigger_sos_usecase.dart';
import '../../../../injection_container.dart';

enum SosStatus { idle, activating, active, cancelling, error }

class SosState {
  final SosStatus status;
  final String? errorMessage;
  final String? alertaId;

  const SosState({
    this.status = SosStatus.idle,
    this.errorMessage,
    this.alertaId,
  });

  bool get isActive => status == SosStatus.active;

  SosState copyWith({
    SosStatus? status,
    String? errorMessage,
    String? alertaId,
  }) =>
      SosState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        alertaId: alertaId ?? this.alertaId,
      );
}

class SosNotifier extends StateNotifier<SosState> {
  final TriggerSosUsecase _usecase;

  SosNotifier(this._usecase) : super(const SosState());

  Future<void> activarSOS({
    required String viajeId,
    required String operadorId,
    required String unidadId,
  }) async {
    state = state.copyWith(status: SosStatus.activating);

    final result = await _usecase(
      viajeId: viajeId,
      operadorId: operadorId,
      unidadId: unidadId,
    );

    result.fold(
      (failure) => state = state.copyWith(
        status: SosStatus.error,
        errorMessage: failure.message,
      ),
      (_) => state = state.copyWith(status: SosStatus.active),
    );
  }

  void cancelarSOS() {
    _usecase.cancelarSOS();
    state = const SosState(status: SosStatus.idle);
  }
}

final sosProvider =
    StateNotifierProvider<SosNotifier, SosState>((ref) {
  return SosNotifier(sl<TriggerSosUsecase>());
});
