/// Exception thrown when the login API returns a business-level error code.
///
/// Carries the server response [code] and [message] so the UI can decide
/// how to present the failure to the user (e.g. a localized toast for
/// password mismatch).
class LoginException implements Exception {
  final int code;
  final String message;

  const LoginException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'LoginException(code: $code, message: $message)';
}
