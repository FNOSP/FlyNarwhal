import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';

const Color _titleTextColor = Color(0xE6FFFFFF);
const Color _secondaryTextColor = Color(0xC8FFFFFF);
const double _columnGap = 24;

const Map<int, String> _transcodingReasonMap = {
  1: '根据视频质量设置降低画质',
  2: '字幕烧录',
  3: '字幕转为 vtt 切片',
  4: '视频格式转换',
  5: '音频格式转换',
  6: '色调映射',
};

const Map<int, String> _decodeMethodLabels = {
  0: '软解码',
  1: 'QSV 解码',
  2: 'VAAPI 解码',
  3: 'NVDEC 解码',
  4: 'RKMPP 解码',
};

const Map<int, String> _encodeMethodLabels = {
  0: '软编码',
  1: 'QSV 编码',
  2: 'QSV 低电压编码',
  3: 'VAAPI 编码',
  4: 'NVENC 编码',
  5: 'RKMPP 编码',
};

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
    return cloudType != null && cloudType > 0;
  }

  String get _playTypeLabel {
    if (cache.isUseDirectLink && _isCloudMedia) {
      // The web player shows a dedicated label for STRM direct-link sessions.
      if (cache.streamInfo?.cloudStorageInfo?.isStrm ?? false) {
        return 'STRM 直连播放';
      }
      return '网盘直连播放';
    }
    if (_isTranscoded) return '转码播放';
    return '直接播放';
  }

  String get _transcodingReasonText {
    final reasons = transcodeStatus?.transcodingReason ?? const <int>[];
    return reasons
        .map((reason) => _transcodingReasonMap[reason])
        .whereType<String>()
        .join('；');
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
                    _detailLine('播放类型', _playTypeLabel),
                    if (_isTranscoded &&
                        _transcodingReasonText.isNotEmpty)
                      _detailLine('转码原因', _transcodingReasonText),
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
            _sectionTitle('播放信息'),
            const SizedBox(height: 8),
            _buildPlaybackInfoRows(),
            const SizedBox(height: 16),
          ],
          _sectionTitle('媒体源信息'),
          const SizedBox(height: 8),
          if (videoStream?.wrapper.isNotEmpty ?? false)
            _detailLine('封装容器', videoStream!.wrapper),
          if (fileStream != null && fileStream.size > 0)
            _detailLine(
              '文件大小',
              FileUtils.formatFileSize(fileStream.size),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildVideoGroup(videoStream)),
              const SizedBox(width: _columnGap),
              Expanded(child: _buildAudioGroup(audioStream)),
            ],
          ),
        ],
      ),
    );
  }

  /// Two-column playback statistics matching the web layout: buffering and
  /// stream info on the left, GPU/codec methods and frame counters on the
  /// right.
  Widget _buildPlaybackInfoRows() {
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
        _detailLine('缓冲时长', '${bufferedSeconds!.toStringAsFixed(2)} s'),
      if (resolution.isNotEmpty) _detailLine('分辨率', resolution),
      if (bitrate > 0) _detailLine('码率', _formatBitrate(bitrate)),
    ];
    final right = <Widget>[];
    if (hasServerStats) {
      final video = status.video;
      if (_isTranscoded) {
        left.addAll([
          if (video.encoder.isNotEmpty) _detailLine('编码器', video.encoder),
          if (video.dynamicRange.isNotEmpty)
            _detailLine('视频动态范围', video.dynamicRange),
          if (status.audio.encoder.isNotEmpty)
            _detailLine('音频编码', status.audio.encoder),
          _detailLine('声道', '${status.audio.channels}'),
        ]);
      }
      right.addAll([
        if (video.selectedGpu.isNotEmpty)
          _detailLine('启用 GPU', video.selectedGpu),
        if (_decodeMethodLabels[video.decodeMethod] != null)
          _detailLine('解码方式', _decodeMethodLabels[video.decodeMethod]!),
        if (_encodeMethodLabels[video.encodeMethod] != null)
          _detailLine('编码方式', _encodeMethodLabels[video.encodeMethod]!),
        if (_isTranscoded) ...[
          if (video.transcodingRate.isNotEmpty)
            _detailLine('转码帧率', video.transcodingRate),
          _detailLine('丢帧', '${video.droppedFrames}'),
          _detailLine('坏帧', '${video.corruptedFrames}'),
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

  Widget _buildVideoGroup(VideoStream? videoStream) {
    if (videoStream == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader('assets/images/vedio.svg', '视频'),
        const SizedBox(height: 8),
        if (videoStream.codecName.isNotEmpty)
          _detailLine('编码', videoStream.codecName.toUpperCase()),
        if (videoStream.colorRangeType.isNotEmpty)
          _detailLine('动态范围', videoStream.colorRangeType),
        if (videoStream.width > 0 && videoStream.height > 0)
          _detailLine('分辨率', '${videoStream.width} x ${videoStream.height}'),
        if (videoStream.bps > 0)
          _detailLine('码率', _formatBitrate(videoStream.bps)),
        if (videoStream.avgFrameRate.isNotEmpty)
          _detailLine('帧率', videoStream.avgFrameRate),
      ],
    );
  }

  Widget _buildAudioGroup(AudioStream? audioStream) {
    if (audioStream == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader('assets/images/audio.svg', '音频'),
        const SizedBox(height: 8),
        if (audioStream.codecName.isNotEmpty)
          _detailLine('编码', audioStream.codecName.toUpperCase()),
        if (audioStream.channels > 0)
          _detailLine('声道', '${audioStream.channels}'),
        if (audioStream.bps > 0)
          _detailLine('码率', _formatBitrate(audioStream.bps)),
        if (audioStream.sampleRate.isNotEmpty)
          _detailLine('采样率', '${audioStream.sampleRate} Hz'),
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

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$label： $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
      ),
    );
  }
}
