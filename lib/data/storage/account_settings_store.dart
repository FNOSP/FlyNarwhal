import 'package:shared_preferences/shared_preferences.dart';

/// Stores settings in explicit global and account-GUID namespaces.
class AccountSettingsStore {
  AccountSettingsStore(this._preferences);

  static const String schemaVersionKey = 'schema.version';
  static const String currentAccountIdKey = 'session.currentAccountId';
  static const int currentSchemaVersion = 1;

  final SharedPreferences _preferences;

  String globalKey(String setting) => 'global.$setting';

  String accountKey({required String guid, required String setting}) {
    final normalizedGuid = guid.trim();
    if (normalizedGuid.isEmpty) {
      throw ArgumentError.value(guid, 'guid', 'Account GUID must not be empty');
    }
    return 'account.$normalizedGuid.$setting';
  }

  Future<void> initializeSchema() async {
    final persistedSchemaVersion = _preferences.getInt(schemaVersionKey) ?? 0;
    if (persistedSchemaVersion > currentSchemaVersion) {
      throw StateError('Stored settings schema is newer than this application');
    }
    if (persistedSchemaVersion != currentSchemaVersion) {
      await _preferences.setInt(schemaVersionKey, currentSchemaVersion);
    }
  }

  String? getCurrentAccountGuid() =>
      _preferences.getString(currentAccountIdKey);

  Future<void> setCurrentAccountGuid(String? guid) async {
    final normalizedGuid = guid?.trim() ?? '';
    if (normalizedGuid.isEmpty) {
      await _preferences.remove(currentAccountIdKey);
      return;
    }
    await _preferences.setString(currentAccountIdKey, normalizedGuid);
  }

  T? readGlobal<T>(String setting) =>
      _preferences.get(globalKey(setting)) as T?;

  T? readAccount<T>({required String guid, required String setting}) {
    return _preferences.get(accountKey(guid: guid, setting: setting)) as T?;
  }

  Future<void> writeGlobal(String setting, Object value) {
    return _write(globalKey(setting), value);
  }

  Future<void> writeAccount({
    required String guid,
    required String setting,
    required Object value,
  }) {
    return _write(accountKey(guid: guid, setting: setting), value);
  }

  Future<void> removeGlobal(String setting) {
    return _preferences.remove(globalKey(setting));
  }

  Future<void> removeAccount({required String guid, required String setting}) {
    return _preferences.remove(accountKey(guid: guid, setting: setting));
  }

  Future<void> _write(String key, Object value) {
    if (value is String) {
      return _preferences.setString(key, value);
    }
    if (value is bool) {
      return _preferences.setBool(key, value);
    }
    if (value is int) {
      return _preferences.setInt(key, value);
    }
    if (value is double) {
      return _preferences.setDouble(key, value);
    }
    if (value is List<String>) {
      return _preferences.setStringList(key, value);
    }
    throw ArgumentError.value(
        value, 'value', 'Unsupported preference value type');
  }
}
