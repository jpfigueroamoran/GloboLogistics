import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Error de servidor.']);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión. Guardado localmente.']);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'No autorizado.']);
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Error de caché local.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permisos insuficientes.']);
}
