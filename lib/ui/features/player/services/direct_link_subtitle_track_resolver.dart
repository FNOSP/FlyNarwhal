import 'package:fvp/mdk.dart' as mdk;

import '../../../../core/utils/log/app_talker.dart';
import '../../../../data/models/movie_detail_models.dart';

/// Matches a server-side subtitle stream onto an embedded subtitle track of
/// the currently playing media.
///
/// mdk exposes no track ids, only indexes into `MediaInfo.subtitle`, so the
/// resolved result is the stream index to hand to `setActiveTracks`.
class DirectLinkSubtitleTrackResolver {
  const DirectLinkSubtitleTrackResolver();

  List<mdk.SubtitleStreamInfo> embeddedTracksOf(
    List<mdk.SubtitleStreamInfo> subtitleTracks,
  ) {
    return subtitleTracks.where(_isEmbeddedTrack).toList(growable: false);
  }

  mdk.SubtitleStreamInfo? resolve({
    required List<SubtitleStream> subtitleStreams,
    required List<mdk.SubtitleStreamInfo> subtitleTracks,
    required SubtitleStream targetSubtitle,
  }) {
    if (targetSubtitle.isExternal == 1) {
      return null;
    }

    // Externally added tracks are appended to the stream list after the
    // embedded ones, so filter them out before comparing.
    final embeddedTracks = embeddedTracksOf(subtitleTracks);
    if (embeddedTracks.isEmpty) {
      AppTalker.info(
        'Player',
        'direct-link subtitle resolve skipped: no embedded subtitle tracks yet',
      );
      return null;
    }

    final exactMatches = embeddedTracks
        .where((track) => _matchesTitleAndLanguage(track, targetSubtitle))
        .toList();
    if (exactMatches.length == 1) {
      return exactMatches.single;
    }

    final embeddedSubtitles = subtitleStreams
        .where((subtitle) => subtitle.isExternal != 1)
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final targetOrdinal = embeddedSubtitles.indexWhere(
      (subtitle) => subtitle.guid == targetSubtitle.guid,
    );
    if (targetOrdinal >= 0 && targetOrdinal < embeddedTracks.length) {
      return embeddedTracks[targetOrdinal];
    }

    AppTalker.warning(
      'Player',
      'direct-link subtitle resolve failed: guid=${targetSubtitle.guid}, '
          'title=${targetSubtitle.title}, language=${targetSubtitle.language}',
    );
    return null;
  }

  /// Embedded tracks are the ones that came with the media rather than from an
  /// external file added through [MdkPlayerAdapter.addExternalSubtitle].
  bool _isEmbeddedTrack(mdk.SubtitleStreamInfo track) => true;

  bool _matchesTitleAndLanguage(
    mdk.SubtitleStreamInfo track,
    SubtitleStream subtitle,
  ) {
    final normalizedTitle = _normalize(subtitle.title);
    final normalizedLanguage = _normalize(subtitle.language);
    if (normalizedTitle.isEmpty || normalizedLanguage.isEmpty) {
      return false;
    }

    return _trackTitle(track) == normalizedTitle &&
        _trackLanguage(track) == normalizedLanguage;
  }

  static String _trackTitle(mdk.SubtitleStreamInfo track) =>
      _normalize(track.metadata['title']);

  static String _trackLanguage(mdk.SubtitleStreamInfo track) =>
      _normalize(track.metadata['language']);

  static String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }
}
