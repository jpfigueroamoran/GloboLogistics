import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';

/// Cola offline-first para actividades pendientes de sincronización.
/// Persiste en Hive y se consume cuando el dispositivo recupera conectividad.
class LocalQueueDatasource {
  Box<Map>? _actividadesBox;
  Box<Map>? _costosBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _actividadesBox =
        await Hive.openBox<Map>(AppConstants.hiveBoxActividades);
    _costosBox =
        await Hive.openBox<Map>(AppConstants.hiveBoxCostos);
  }

  Future<void> encolarActividad(
      String id, Map<String, dynamic> data) async {
    await _actividadesBox!.put(id, data);
  }

  Map<String, Map<String, dynamic>> getActividadesPendientes() {
    final raw = _actividadesBox!.toMap();
    return {
      for (final key in raw.keys)
        key.toString(): Map<String, dynamic>.from(raw[key] as Map),
    };
  }

  Future<void> eliminarActividad(String id) async {
    await _actividadesBox!.delete(id);
  }

  Future<void> limpiarActividadesSincronizadas(
      List<String> ids) async {
    await _actividadesBox!.deleteAll(ids);
  }

  Future<void> encolarCosto(String id, Map<String, dynamic> data) async {
    await _costosBox!.put(id, data);
  }

  Map<String, Map<String, dynamic>> getCostosPendientes() {
    final raw = _costosBox!.toMap();
    return {
      for (final key in raw.keys)
        key.toString(): Map<String, dynamic>.from(raw[key] as Map),
    };
  }

  Future<void> limpiarCostosSincronizados(List<String> ids) async {
    await _costosBox!.deleteAll(ids);
  }

  bool get hayActividadesPendientes =>
      (_actividadesBox?.isNotEmpty) ?? false;
}
