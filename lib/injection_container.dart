import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';

import 'core/network/connectivity_service.dart';
import 'core/services/storage_service.dart';
import 'data/datasources/local/local_queue_datasource.dart';
import 'data/datasources/remote/cliente_firestore_datasource.dart';
import 'data/datasources/remote/firestore_datasource.dart';
import 'data/repositories/actividad_repository_impl.dart';
import 'data/repositories/cliente_repository_impl.dart';
import 'data/repositories/seguridad_repository_impl.dart';
import 'data/repositories/viaje_repository_impl.dart';
import 'domain/repositories/i_actividad_repository.dart';
import 'domain/repositories/i_cliente_repository.dart';
import 'domain/repositories/i_seguridad_repository.dart';
import 'domain/repositories/i_viaje_repository.dart';
import 'domain/usecases/actividad/sync_actividades_usecase.dart';
import 'domain/usecases/auditoria/auditoria_diesel_usecase.dart';
import 'domain/usecases/seguridad/trigger_sos_usecase.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Firebase ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseStorage.instance);

  // ── Core ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => ConnectivityService());
  sl.registerLazySingleton(() => StorageService(sl()));

  // ── DataSources ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<FirestoreDatasource>(
      () => FirestoreDatasource(sl()));

  sl.registerLazySingleton<ClienteFirestoreDatasource>(
      () => ClienteFirestoreDatasource(sl()));

  final localQueue = LocalQueueDatasource();
  await localQueue.init();
  sl.registerSingleton<LocalQueueDatasource>(localQueue);

  // ── Repositories ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<IViajeRepository>(
      () => ViajeRepositoryImpl(sl()));

  sl.registerLazySingleton<IClienteRepository>(
      () => ClienteRepositoryImpl(sl()));

  sl.registerLazySingleton<IActividadRepository>(
      () => ActividadRepositoryImpl(sl(), sl(), sl()));

  sl.registerLazySingleton<ISeguridadRepository>(
      () => SeguridadRepositoryImpl(sl()));

  // ── Use Cases ─────────────────────────────────────────────────────────────
  sl.registerFactory(() => TriggerSosUsecase(sl()));
  sl.registerFactory(() => SyncActividadesUsecase(sl(), sl()));
  sl.registerFactory(() => AuditoriaDieselUsecase(sl()));
}
