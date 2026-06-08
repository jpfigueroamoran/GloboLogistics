import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';
import '../../../../injection_container.dart';

enum PasoWizard { origen, destinos, confirmar }

class IniciarViajeState {
  final PasoWizard paso;
  final String? origenDescripcion;
  final GeoPoint? origenGeo;
  final List<Cliente> destinosSeleccionados;
  final bool loading;
  final String? error;
  final String? viajeCreado;

  const IniciarViajeState({
    this.paso = PasoWizard.origen,
    this.origenDescripcion,
    this.origenGeo,
    this.destinosSeleccionados = const [],
    this.loading = false,
    this.error,
    this.viajeCreado,
  });

  IniciarViajeState copyWith({
    PasoWizard? paso,
    String? origenDescripcion,
    GeoPoint? origenGeo,
    List<Cliente>? destinosSeleccionados,
    bool? loading,
    String? error,
    String? viajeCreado,
  }) =>
      IniciarViajeState(
        paso:                  paso                  ?? this.paso,
        origenDescripcion:     origenDescripcion     ?? this.origenDescripcion,
        origenGeo:             origenGeo             ?? this.origenGeo,
        destinosSeleccionados: destinosSeleccionados ?? this.destinosSeleccionados,
        loading:               loading               ?? this.loading,
        error:                 error,
        viajeCreado:           viajeCreado           ?? this.viajeCreado,
      );
}

class IniciarViajeNotifier extends StateNotifier<IniciarViajeState> {
  final IViajeRepository _viajeRepo;

  IniciarViajeNotifier(this._viajeRepo) : super(const IniciarViajeState());

  void setOrigen(String descripcion, {GeoPoint? geo}) {
    state = state.copyWith(
      origenDescripcion: descripcion,
      origenGeo:         geo,
      paso:              PasoWizard.destinos,
    );
  }

  void agregarDestino(Cliente cliente) {
    if (state.destinosSeleccionados.any((c) => c.id == cliente.id)) return;
    state = state.copyWith(
      destinosSeleccionados: [...state.destinosSeleccionados, cliente],
    );
  }

  void quitarDestino(String clienteId) {
    state = state.copyWith(
      destinosSeleccionados:
          state.destinosSeleccionados.where((c) => c.id != clienteId).toList(),
    );
  }

  void irAConfirmar() {
    if (state.destinosSeleccionados.isEmpty) return;
    state = state.copyWith(paso: PasoWizard.confirmar);
  }

  void irAtras() {
    state = state.copyWith(
      paso: state.paso == PasoWizard.confirmar
          ? PasoWizard.destinos
          : PasoWizard.origen,
    );
  }

  Future<void> crearViaje({
    required String operadorId,
    required String unidadId,
  }) async {
    if (state.origenDescripcion == null ||
        state.destinosSeleccionados.isEmpty) return;

    state = state.copyWith(loading: true, error: null);

    try {
      final ahora = DateTime.now();
      final id = const Uuid().v4();

      final destinos = state.destinosSeleccionados
          .asMap()
          .entries
          .map((e) => Destino(
                clienteId:   e.value.id,
                descripcion: e.value.nombre,
                geo:         e.value.posicion,
                orden:       e.key + 1,
              ))
          .toList();

      final viaje = Viaje(
        id:                  id,
        unidadId:            unidadId,
        operadorId:          operadorId,
        origenDescripcion:   state.origenDescripcion!,
        destinoDescripcion:  destinos.last.descripcion,
        origenGeo:           state.origenGeo,
        destinoGeo:          destinos.last.geo,
        destinos:            destinos,
        estado:              EstadoViaje.enCurso,
        fechaInicio:         ahora,
        createdAt:           ahora,
        updatedAt:           ahora,
      );

      final result = await _viajeRepo.crearViaje(viaje);
      result.fold(
        (f) => state = state.copyWith(loading: false, error: f.message),
        (vId) => state = state.copyWith(loading: false, viajeCreado: vId),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void reset() => state = const IniciarViajeState();
}

final iniciarViajeProvider =
    StateNotifierProvider.autoDispose<IniciarViajeNotifier, IniciarViajeState>(
  (ref) => IniciarViajeNotifier(sl<IViajeRepository>()),
);
