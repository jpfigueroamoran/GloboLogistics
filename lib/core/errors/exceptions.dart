class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Error de servidor.']);
}

class NetworkException implements Exception {
  const NetworkException();
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'No autorizado.']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Error de caché.']);
}
