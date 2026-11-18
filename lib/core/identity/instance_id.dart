import 'dart:io';
import 'dart:math';

/// Format: `<os>-<arch>-fn-<16 hex>` — e.g. `macos-arm64-fn-3f9a2b7c14d8e6a0`.
/// The first three segments describe how the instance was born and never
/// change; the random tail is what makes it unique per install.
const String instanceIdClient = 'fn';

/// Client tag of the id the launch-report sends as `deviceId`; it is not an
/// instance id even though it shares the shape.
const String legacyReportClientTag = 'fly';
const int instanceIdRandomHexLength = 16;

String buildInstanceId({
  required String os,
  required String arch,
  required String randomHex,
  String client = instanceIdClient,
}) {
  return '${normalizeInstanceIdSegment(os)}-'
      '${normalizeInstanceIdSegment(arch)}-'
      '$client-$randomHex';
}

String generateInstanceId({
  required String os,
  required String arch,
  Random? random,
  String client = instanceIdClient,
}) {
  return buildInstanceId(
    os: os,
    arch: arch,
    randomHex: generateInstanceIdRandomHex(random),
    client: client,
  );
}

String generateInstanceIdRandomHex([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < instanceIdRandomHexLength; i++) {
    buffer.write(source.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}

/// Rebuilds an id from any earlier format into `<os>-<arch>-fn-<random>`.
/// The old tag (`flutter_`/`jvm_`) is dropped; a UUID keeps its random part.
String toInstanceIdFormat(
  String legacyId, {
  required String os,
  required String arch,
}) {
  final randomHex = legacyId
      .toLowerCase()
      .replaceFirst(RegExp(r'^(flutter|jvm)_'), '')
      .replaceAll(RegExp('[^a-f0-9]'), '');
  return buildInstanceId(
    os: os,
    arch: arch,
    randomHex: randomHex.isEmpty
        ? generateInstanceIdRandomHex()
        : randomHex.substring(0, randomHex.length.clamp(0, 32)),
  );
}

/// Lowercase alphanumerics only, so segments never carry whatever
/// separators the OS/arch sources use.
String normalizeInstanceIdSegment(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

/// Derives the os/arch segments from the current process.
///
/// [Platform.operatingSystem] already uses the names we want (`windows`,
/// `macos`, `linux`); the architecture comes from [Platform.version], whose
/// first token is `arm64` / `arm` / `ia32` / `x64`.
({String os, String arch}) resolveInstanceIdEnvironment() {
  final arch = Platform.version.trim().split(RegExp(r'\s+')).first;
  return (os: Platform.operatingSystem, arch: arch);
}
