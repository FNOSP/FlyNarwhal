import '../../../core/version/semantic_version.dart';

/// Persisted lifecycle stages for a downloaded update package.
enum UpdateDownloadStage { downloading, verified, failed }

/// Stable reasons why a persisted download record cannot be trusted.
enum UpdateDownloadRecordFailureReason {
  corrupted,
  unsupportedSchema,
  invalidField,
  pathRejected,
}

/// A diagnosable failure while reading an untrusted download record.
final class UpdateDownloadRecordException implements Exception {
  const UpdateDownloadRecordException(this.reason, this.message);

  final UpdateDownloadRecordFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// Typed, schema-versioned state used to recover downloads across processes.
final class UpdateDownloadRecord {
  const UpdateDownloadRecord({
    required this.schemaVersion,
    required this.version,
    required this.assetName,
    required this.officialDownloadUrl,
    required this.expectedSize,
    required this.expectedSha256,
    required this.finalFilePath,
    required this.stage,
    required this.automaticFailureCount,
    required this.lastFailureCode,
    required this.lastFailureAt,
    required this.updatedAt,
  });

  static const int currentSchemaVersion = 1;
  static final RegExp _sha256Expression = RegExp(r'^sha256:[a-fA-F0-9]{64}$');

  final int schemaVersion;
  final String version;
  final String assetName;
  final Uri officialDownloadUrl;
  final int expectedSize;
  final String expectedSha256;
  final String finalFilePath;
  final UpdateDownloadStage stage;
  final int automaticFailureCount;
  final String? lastFailureCode;
  final DateTime? lastFailureAt;
  final DateTime updatedAt;

  factory UpdateDownloadRecord.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != currentSchemaVersion) {
      throw const UpdateDownloadRecordException(
        UpdateDownloadRecordFailureReason.unsupportedSchema,
        'Unsupported update download record schema.',
      );
    }

    try {
      final version = _requiredString(json, 'version');
      final assetName = _requiredString(json, 'assetName');
      final officialDownloadUrl =
          Uri.parse(_requiredString(json, 'officialDownloadUrl'));
      final expectedSize = json['expectedSize'];
      final expectedSha256 = _requiredString(json, 'expectedSha256');
      final finalFilePath = _requiredString(json, 'finalFilePath');
      final stage = UpdateDownloadStage.values.byName(
        _requiredString(json, 'stage'),
      );
      final automaticFailureCount = json['automaticFailureCount'];
      final lastFailureCode = json['lastFailureCode'];
      final lastFailureAt = _optionalDateTime(json['lastFailureAt']);
      final updatedAt = DateTime.parse(_requiredString(json, 'updatedAt'));

      final hasValidVersion = SemanticVersion.tryParse(version) != null;
      final hasValidUrl = officialDownloadUrl.scheme.toLowerCase() == 'https' &&
          officialDownloadUrl.host.isNotEmpty;
      final hasValidFailureCode =
          lastFailureCode == null || lastFailureCode is String;
      if (!hasValidVersion ||
          assetName.isEmpty ||
          !hasValidUrl ||
          expectedSize is! int ||
          expectedSize <= 0 ||
          !_sha256Expression.hasMatch(expectedSha256) ||
          finalFilePath.isEmpty ||
          automaticFailureCount is! int ||
          automaticFailureCount < 0 ||
          !hasValidFailureCode) {
        throw const UpdateDownloadRecordException(
          UpdateDownloadRecordFailureReason.invalidField,
          'Update download record contains an invalid field.',
        );
      }

      return UpdateDownloadRecord(
        schemaVersion: schemaVersion as int,
        version: version,
        assetName: assetName,
        officialDownloadUrl: officialDownloadUrl,
        expectedSize: expectedSize,
        expectedSha256: expectedSha256.toLowerCase(),
        finalFilePath: finalFilePath,
        stage: stage,
        automaticFailureCount: automaticFailureCount,
        lastFailureCode: lastFailureCode as String?,
        lastFailureAt: lastFailureAt,
        updatedAt: updatedAt.toUtc(),
      );
    } on UpdateDownloadRecordException {
      rethrow;
    } on Object {
      throw const UpdateDownloadRecordException(
        UpdateDownloadRecordFailureReason.invalidField,
        'Update download record contains an invalid field.',
      );
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'version': version,
      'assetName': assetName,
      'officialDownloadUrl': officialDownloadUrl.toString(),
      'expectedSize': expectedSize,
      'expectedSha256': expectedSha256,
      'finalFilePath': finalFilePath,
      'stage': stage.name,
      'automaticFailureCount': automaticFailureCount,
      'lastFailureCode': lastFailureCode,
      'lastFailureAt': lastFailureAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  UpdateDownloadRecord copyWith({
    UpdateDownloadStage? stage,
    int? automaticFailureCount,
    String? lastFailureCode,
    DateTime? lastFailureAt,
    DateTime? updatedAt,
  }) {
    return UpdateDownloadRecord(
      schemaVersion: schemaVersion,
      version: version,
      assetName: assetName,
      officialDownloadUrl: officialDownloadUrl,
      expectedSize: expectedSize,
      expectedSha256: expectedSha256,
      finalFilePath: finalFilePath,
      stage: stage ?? this.stage,
      automaticFailureCount:
          automaticFailureCount ?? this.automaticFailureCount,
      lastFailureCode: lastFailureCode ?? this.lastFailureCode,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UpdateDownloadRecord &&
        other.schemaVersion == schemaVersion &&
        other.version == version &&
        other.assetName == assetName &&
        other.officialDownloadUrl == officialDownloadUrl &&
        other.expectedSize == expectedSize &&
        other.expectedSha256 == expectedSha256 &&
        other.finalFilePath == finalFilePath &&
        other.stage == stage &&
        other.automaticFailureCount == automaticFailureCount &&
        other.lastFailureCode == lastFailureCode &&
        other.lastFailureAt == lastFailureAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        version,
        assetName,
        officialDownloadUrl,
        expectedSize,
        expectedSha256,
        finalFilePath,
        stage,
        automaticFailureCount,
        lastFailureCode,
        lastFailureAt,
        updatedAt,
      );

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw const UpdateDownloadRecordException(
        UpdateDownloadRecordFailureReason.invalidField,
        'Update download record contains a missing string field.',
      );
    }
    return value;
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid optional date.');
    }
    return DateTime.parse(value).toUtc();
  }
}
