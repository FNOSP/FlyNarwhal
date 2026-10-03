import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../data/models/cloud_storage_type.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';
import '../../../../l10n/generated/app_localizations.dart';

const Color _titleTextColor = Color(0xE6FFFFFF);
const Color _secondaryTextColor = Color(0xC8FFFFFF);
const double _columnGap = 24;

// Server enum -> localized label for the transcode reason list. The int keys
// are the stable logic identifiers; only the labels are user-visible.
String? _transcodingReasonLabel(AppLocalizations l10n, int reason) {
  switch (reason) {
    case 1:
      return l10n.playerTranscodeReasonLowerQuality;
    case 2:
      return l10n.playerTranscodeReasonSubtitleBurn;
    case 3:
      return l10n.playerTranscodeReasonSubtitleToVtt;
    case 4:
      return l10n.playerTranscodeReasonVideoFormat;
    case 5:
      return l10n.playerTranscodeReasonAudioFormat;
    case 6:
      return l10n.playerTranscodeReasonToneMapping;
    default:
      return null;
  }
}

String? _decodeMethodLabel(AppLocalizations l10n, int method) {
  switch (method) {
    case 0:
      return l10n.playerDecodeMethodSoftware;
    case 1:
      return l10n.playerDecodeMethodQsv;
    case 2:
      return l10n.playerDecodeMethodVaapi;
    case 3:
      return l10n.playerDecodeMethodNvdec;
    case 4:
      return l10n.playerDecodeMethodRkmpp;
    default:
      return null;
  }
}

String? _encodeMethodLabel(AppLocalizations l10n, int method) {
  switch (method) {
    case 0:
      return l10n.playerEncodeMethodSoftware;
    case 1:
      return l10n.playerEncodeMethodQsv;
    case 2:
      return l10n.playerEncodeMethodQsvLowPower;
    case 3:
      return l10n.playerEncodeMethodVaapi;
    case 4:
      return l10n.playerEncodeMethodNvenc;
    case 5:
      return l10n.playerEncodeMethodRkmpp;
    default:
      return null;
  }
}

// Matches the web player's bitrate rendering, e.g. 24556026 -> "24.56 Mbps",
// 768000 -> "768 Kbps", 20000000 -> "20 Mbps".
String _formatBitrate(int bps) {
  if (bps <= 0) return '0 bps';
  if (bps >= 1000000) {
    return '${_trimTrailingZeros((bps / 1000000).toStringAsFixed(2))} Mbps';
  }
  if (bps >= 1000) {
    return '${(bps / 1000).toStringAsFixed(0)} Kbps';
  }
  return '$bps bps';
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;
  return value.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Top-right playback details panel mirroring the web player's
/// “播放详细信息” overlay: play type, live playback/transcode statistics and
/// the media source information (container / file size / video / audio).
///
/// Renders only the content; the surface is provided by the liquid glass
/// container wrapping it (see `PlaybackDetailsMorph`).
class PlaybackDetailsPanel extends StatelessWidget {
  final PlayingInfoCache cache;
  final MediaTranscodeResponse? transcodeStatus;
  final double? bufferedSeconds;

  const PlaybackDetailsPanel({
    super.key,
    required this.cache,
    this.transcodeStatus,
    this.bufferedSeconds,
  });

  bool get _isTranscoded => transcodeStatus?.transcoded ?? false;

  // The app treats any original-file session as "direct link", while the web
  // reserves 网盘直连播放 for cloud-storage media; local files fall through to
  // 直接播放 / 转码播放 based on the transcode statistics.
  bool get _isCloudMedia {
    final cloudType = cache.streamInfo?.cloudStorageInfo?.cloudStorageType;
    return CloudStorageType.fromValue(cloudType).isKnown;
  }

  String _playTypeLabel(AppLocalizations l10n) {
    if (cache.isUseDirectLink && _isCloudMedia) {
      // The web player shows a dedicated label for STRM direct-link sessions.
      return cache.streamInfo?.cloudStorageInfo?.isStrm ?? false
          ? l10n.playerPlayTypeStrmDirect
          : l10n.playerCloudModeDirect;
    }
    if (_isTranscoded) return l10n.playerPlayTypeTranscode;
    return l10n.playerPlayTypeDirect;
  }

  String _transcodingReasonText(AppLocalizations l10n) {
    final reasons = transcodeStatus?.transcodingReason ?? const <int>[];
    return reasons
        .map((reason) => _transcodingReasonLabel(l10n, reason))
        .whereType<String>()
        .join(l10n.playerTranscodeReasonSeparator);
  }

  bool get _hasPlaybackInfo {
    final status = transcodeStatus;
    if (status != null && status.result == 'succ') return true;
    // Direct-link sessions have no server-side transcode statistics, so the
    // playback info falls back to the client buffer duration and the media
    // source stream's resolution / bitrate.
    if (!cache.isUseDirectLink) return false;
    final video = cache.currentVideoStream;
    if (video != null &&
        (video.width > 0 && video.height > 0 || video.bps > 0)) {
      return true;
    }
    return bufferedSeconds != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fileStream = cache.currentFileStream;
    final videoStream = cache.currentVideoStream;
    final audioStream = cache.currentAudioStream;

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailLine(
                        context, l10n.playerPlayType, _playTypeLabel(l10n)),
                    if (_isTranscoded &&
                        _transcodingReasonText(l10n).isNotEmpty)
                      _detailLine(context, l10n.playerTranscodeReason,
                          _transcodingReasonText(l10n)),
                  ],
                ),
              ),
              // Reserve space for the fixed close button that lives outside
              // the scroll view so content doesn't run underneath it.
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 16),
          if (_hasPlaybackInfo) ...[
            _sectionTitle(l10n.playerPlaybackInfo),
            const SizedBox(height: 8),
            _buildPlaybackInfoRows(context),
            const SizedBox(height: 16),
          ],
          _sectionTitle(l10n.playerMediaSourceInfo),
          const SizedBox(height: 8),
          if (videoStream?.wrapper.isNotEmpty ?? false)
            _detailLine(context, l10n.playerContainerFormat, videoStream!.wrapper),
          if (fileStream != null && fileStream.size > 0)
            _detailLine(
              context,
              l10n.mediaInfoFileSize,
              FileUtils.formatFileSize(fileStream.size),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildVideoGroup(context, videoStream)),
              const SizedBox(width: _columnGap),
              Expanded(child: _buildAudioGroup(context, audioStream)),
            ],
          ),
        ],
      ),
    );
  }

  /// Two-column playback statistics matching the web layout: buffering and
  /// stream info on the left, GPU/codec methods and frame counters on the
  /// right.
  Widget _buildPlaybackInfoRows(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = transcodeStatus;
    final hasServerStats = status != null && status.result == 'succ';
    final videoStream = cache.currentVideoStream;

    // Transcoded/server sessions report the effective output resolution and
    // bitrate; direct play falls back to the media source stream's values.
    final resolution = hasServerStats && status.resolution.isNotEmpty
        ? status.resolution
        : videoStream != null && videoStream.width > 0 && videoStream.height > 0
            ? '${videoStream.width} x ${videoStream.height}'
            : '';
    final bitrate = hasServerStats && status.bitrate > 0
        ? status.bitrate
        : videoStream?.bps ?? 0;

    final left = <Widget>[
      if (bufferedSeconds != null)
        _detailLine(context, l10n.playerBufferDuration,
            '${bufferedSeconds!.toStringAsFixed(2)} s'),
      if (resolution.isNotEmpty)
        _detailLine(context, l10n.mediaInfoFieldResolution, resolution),
      if (bitrate > 0)
        _detailLine(context, l10n.mediaInfoFieldBitRate, _formatBitrate(bitrate)),
    ];
    final right = <Widget>[];
    if (hasServerStats) {
      final video = status.video;
      if (_isTranscoded) {
        left.addAll([
          if (video.encoder.isNotEmpty)
            _detailLine(context, l10n.mediaInfoFieldCodec, video.encoder),
          if (video.dynamicRange.isNotEmpty)
            _detailLine(
                context, l10n.mediaInfoFieldDynamicRange, video.dynamicRange),
          if (status.audio.encoder.isNotEmpty)
            _detailLine(context, l10n.playerAudioCodec, status.audio.encoder),
          _detailLine(
              context, l10n.mediaInfoFieldChannels, '${status.audio.channels}'),
        ]);
      }
      right.addAll([
        if (video.selectedGpu.isNotEmpty)
          _detailLine(context, l10n.playerGpuEnabled, video.selectedGpu),
        if (_decodeMethodLabel(l10n, video.decodeMethod) != null)
          _detailLine(context, l10n.playerDecodeMethod,
              _decodeMethodLabel(l10n, video.decodeMethod)!),
        if (_encodeMethodLabel(l10n, video.encodeMethod) != null)
          _detailLine(context, l10n.playerEncodeMethod,
              _encodeMethodLabel(l10n, video.encodeMethod)!),
        if (_isTranscoded) ...[
          if (video.transcodingRate.isNotEmpty)
            _detailLine(
                context, l10n.playerTranscodeFrameRate, video.transcodingRate),
          _detailLine(context, l10n.playerDroppedFrames, '${video.droppedFrames}'),
          _detailLine(
              context, l10n.playerCorruptedFrames, '${video.corruptedFrames}'),
        ],
      ]);
    }

    if (right.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: left,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: left,
          ),
        ),
        const SizedBox(width: _columnGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: right,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoGroup(BuildContext context, VideoStream? videoStream) {
    if (videoStream == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader(
            'assets/images/vedio.svg', l10n.mediaInfoSectionVideo),
        const SizedBox(height: 8),
        if (videoStream.codecName.isNotEmpty)
          _detailLine(
              context, l10n.playerCodec, videoStream.codecName.toUpperCase()),
        if (videoStream.colorRangeType.isNotEmpty)
          _detailLine(context, l10n.playerDynamicRange, videoStream.colorRangeType),
        if (videoStream.width > 0 && videoStream.height > 0)
          _detailLine(context, l10n.mediaInfoFieldResolution,
              '${videoStream.width} x ${videoStream.height}'),
        if (videoStream.bps > 0)
          _detailLine(
              context, l10n.mediaInfoFieldBitRate, _formatBitrate(videoStream.bps)),
        if (videoStream.avgFrameRate.isNotEmpty)
          _detailLine(
              context, l10n.mediaInfoFieldFrameRate, videoStream.avgFrameRate),
      ],
    );
  }

  Widget _buildAudioGroup(BuildContext context, AudioStream? audioStream) {
    if (audioStream == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader(
            'assets/images/audio.svg', l10n.mediaInfoSectionAudio),
        const SizedBox(height: 8),
        if (audioStream.codecName.isNotEmpty)
          _detailLine(
              context, l10n.playerCodec, audioStream.codecName.toUpperCase()),
        if (audioStream.channels > 0)
          _detailLine(
              context, l10n.mediaInfoFieldChannels, '${audioStream.channels}'),
        if (audioStream.bps > 0)
          _detailLine(
              context, l10n.mediaInfoFieldBitRate, _formatBitrate(audioStream.bps)),
        if (audioStream.sampleRate.isNotEmpty)
          _detailLine(context, l10n.mediaInfoFieldSampleRate,
              '${audioStream.sampleRate} Hz'),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _titleTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _groupHeader(String iconAssetPath, String title) {
    return Row(
      children: [
        SvgPicture.asset(
          iconAssetPath,
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(
            _titleTextColor,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _titleTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$label${AppLocalizations.of(context).playerDetailSeparator} $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
      ),
    );
  }
}
