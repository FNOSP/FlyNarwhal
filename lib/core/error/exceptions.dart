/// Base exception class for all custom exceptions
abstract class AppException implements Exception {
  final String message;
  final int? code;

  const AppException({
    required this.message,
    this.code,
  });

  @override
  String toString() => '$runtimeType: $message';
}

/// Network-related exceptions
class NetworkException extends AppException {
  final int? statusCode;
  final dynamic responseData;

  const NetworkException({
    required super.message,
    super.code,
    this.statusCode,
    this.responseData,
  });
}

/// Server error exception
class ServerException extends AppException {
  final int? statusCode;
  final dynamic responseData;

  const ServerException({
    required super.message,
    super.code,
    this.statusCode,
    this.responseData,
  });
}

/// Authentication exception
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
  });
}

/// Cache/storage exception
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
  });
}

/// Parsing/serialization exception
class ParseException extends AppException {
  const ParseException({
    required super.message,
    super.code,
  });
}

/// Validation exception
class ValidationException extends AppException {
  final Map<String, String>? errors;

  const ValidationException({
    required super.message,
    super.code,
    this.errors,
  });
}