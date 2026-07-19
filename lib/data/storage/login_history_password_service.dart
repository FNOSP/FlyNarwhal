import '../../core/security/password_cipher.dart';
import '../models/login_history.dart';

/// Encrypts stored login-history passwords and decrypts them on demand.
class LoginHistoryPasswordService {
  LoginHistoryPasswordService(this._passwordCipher);

  final PasswordCipher _passwordCipher;

  /// Encrypts a non-empty password before it reaches persistent storage.
  Future<String?> encryptForStorage(String? plainPassword) async {
    if (plainPassword == null || plainPassword.isEmpty) {
      return null;
    }
    return _passwordCipher.encrypt(plainPassword);
  }

  /// Resolves a password for display without exposing invalid ciphertext.
  Future<LoginPasswordResult> decryptForDisplay(LoginHistory entry) async {
    final storedPassword = entry.password;
    if (storedPassword == null || storedPassword.isEmpty) {
      return const LoginPasswordResult(password: null, shouldClear: false);
    }
    if (!entry.passwordEncrypted) {
      return LoginPasswordResult(password: storedPassword, shouldClear: false);
    }

    try {
      final plainPassword = await _passwordCipher.decrypt(storedPassword);
      return LoginPasswordResult(password: plainPassword, shouldClear: false);
    } on PasswordCipherException {
      return const LoginPasswordResult(password: null, shouldClear: true);
    }
  }
}

/// Describes a password lookup and whether persisted ciphertext is stale.
class LoginPasswordResult {
  const LoginPasswordResult({
    required this.password,
    required this.shouldClear,
  });

  final String? password;
  final bool shouldClear;
}
