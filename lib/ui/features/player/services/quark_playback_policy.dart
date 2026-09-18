import '../../../../data/models/player_models.dart';

/// Keeps failed Quark single-file attempts from silently switching to NAS.
/// This uses the selected session intent, which survives transport cleanup;
/// HLS and NAS original-file fallbacks retain their existing behavior.
bool shouldBlockQuarkAutomaticNasFallback(
  PlayingInfoCache? cache, {
  required bool Function(DirectLinkQuality quality) isHlsQuality,
}) {
  if (cache == null ||
      cache.streamInfo?.cloudStorageInfo?.cloudStorageType != 4 ||
      !cache.isUseDirectLink ||
      cache.directLinkQualityIndex == null) {
    return false;
  }

  final index = cache.directLinkQualityIndex!;
  if (index < 0 || index >= cache.directLinkQualities.length) {
    return true;
  }
  return !isHlsQuality(cache.directLinkQualities[index]);
}
