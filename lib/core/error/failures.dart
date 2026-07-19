/// Base failure class for all failures in the application
sealed class Failure {
  final String message;
  final int? code;

  const Failure({
    required this.message,
    this.code,
  });

  String get displayMessage => message;
}

/// Network-related failures (connectivity, timeout, etc.)
class NetworkFailure extends Failure {
  final NetworkErrorType type;

  const NetworkFailure({
    required super.message,
    super.code,
    this.type = NetworkErrorType.unknown,
  });

  @override
  String get displayMessage {
    switch (type) {
      case NetworkErrorType.connectionTimeout:
        return 'Connection timeout, please check your network';
      case NetworkErrorType.sendTimeout:
        return 'Request send timeout';
      case NetworkErrorType.receiveTimeout:
        return 'Response receive timeout';
      case NetworkErrorType.badResponse:
        return 'Server returned error response';
      case NetworkErrorType.connectionError:
        return 'Unable to connect to server';
      case NetworkErrorType.unknown:
        return message;
    }
  }
}

enum NetworkErrorType {
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  badResponse,
  connectionError,
  unknown,
}

/// Server-side failures with error code
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
  });
}

/// Authentication/Authorization failures
class AuthFailure extends Failure {
  final AuthErrorType type;

  const AuthFailure({
    required super.message,
    super.code,
    this.type = AuthErrorType.unauthorized,
  });

  @override
  String get displayMessage {
    switch (type) {
      case AuthErrorType.unauthorized:
        return 'Authentication required, please login';
      case AuthErrorType.tokenExpired:
        return 'Session expired, please login again';
      case AuthErrorType.forbidden:
        return 'Access denied';
      case AuthErrorType.invalidCredentials:
        return 'Invalid credentials';
    }
  }
}

enum AuthErrorType {
  unauthorized,
  tokenExpired,
  forbidden,
  invalidCredentials,
}

/// Cache/Local storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
  });
}

/// Unknown/unexpected failures
class UnknownFailure extends Failure {
  final Exception? exception;
  final StackTrace? stackTrace;

  const UnknownFailure({
    required super.message,
    super.code,
    this.exception,
    this.stackTrace,
  });
}