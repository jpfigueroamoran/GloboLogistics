abstract final class AppConstants {
  // Firebase Collections
  static const String colUnidades = 'unidades';
  static const String colViajes = 'viajes';
  static const String colActividadOperativa = 'actividad_operativa';
  static const String colCostosOperativos = 'costos_operativos';
  static const String colAlertasSeguridad = 'alertas_seguridad';
  static const String colUsuarios = 'usuarios';
  static const String colClientes = 'clientes';
  static const String colConfig = 'config';

  // Config docs
  static const String docEmpresa = 'empresa';
  static const String docPricing = 'pricing';

  // SOS
  static const int sosIntervalSeconds = 5;
  static const int sosMaxRetries = 3;

  // Auditoría de Combustible
  static const double varianzaCombustibleUmbral = 0.015; // 1.5 %

  // Geocerca
  static const double geocercaRadioMetros = 500.0;

  // Sync / Offline
  static const String hiveBoxActividades = 'actividades_pendientes';
  static const String hiveBoxCostos = 'costos_pendientes';

  // Roles
  static const String rolOperador = 'operador';
  static const String rolSupervisor = 'supervisor';
  static const String rolAdministrador = 'administrador';
}
