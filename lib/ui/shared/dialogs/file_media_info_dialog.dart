import 'package:fluent_ui/fluent_ui.dart';

import '../../../data/models/movie_detail_models.dart';
import '../../../data/utils/fn_data_convertor.dart';
import 'app_dialog.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

/// 复刻自 http://192.168.31.73:5666 的"文件媒体信息"弹窗。
///
/// 视觉与字段顺序与网页完全一致：每张轨道卡片为三列等宽的"标签:值"列表，
/// 列与列之间用一条 32px 高的竖向分隔线隔开：
/// - 视频：列 1=编码器/配置/等级/分辨率/宽高比，
///   列 2=隔行扫描/帧率/码率/视频动态范围/色彩原色，
///   列 3=色彩空间/色彩转换/位深度/像素格式/参考帧；
/// - 音频：列 1=语言/编码器/配置，列 2=布局/声道/采样率，列 3=码率/默认；
/// - 字幕：列 1=语言/编码器，列 2=默认/强制，列 3=外部。
class FileMediaInfoDialog extends StatelessWidget {
  const FileMediaInfoDialog({
    super.key,
    required this.videoStream,
    required this.audioStreams,
    required this.subtitleStreams,
    required this.iso6391Map,
    required this.iso6392Map,
  });

  /// 详情页当前选中的视频轨（弹窗只展示这一条）。
  final VideoStream? videoStream;

  /// 全部音轨，按媒体文件分别展示。
  final List<AudioStream> audioStreams;

  /// 全部字幕轨，按媒体文件分别展示。
  final List<SubtitleStream> subtitleStreams;

  /// 字幕语言码 -> 本地化的映射。
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;

  static const _textColor0 = Color(0xFFFFFFFF); // --semi-color-text-0
  static const _textColor1 = Color(0xCCFFFFFF); // --semi-color-text-1 (0.8)
  static const _cardSurface = Color(0x0AFFFFFF); // --semi-color-fill-0 (0.04)
  static const _dividerColor = Color(0x1AFFFFFF); // 分隔线 (0.1)

  static const _dialogConstraints = BoxConstraints(
    minWidth: 720,
    maxWidth: 800,
    maxHeight: 880,
  );

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: _dialogConstraints,
      style: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: appDialogDarkSurfaceColor,
          border: Border.all(color: appDialogDarkSecondaryBorderColor),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        barrierColor: const Color(0xB3000000),
        padding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        bodyPadding: EdgeInsets.zero,
      ),
      title: _buildHeader(context),
      content: _buildBody(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '文件媒体信息',
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    color: _textColor0,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
            ),
          ),
          AppIconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 16),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              title: '视频',
              children: [
                if (videoStream != null)
                  _VideoTrackCard(
                      stream: videoStream!,
                      iso6391Map: iso6391Map,
                      iso6392Map: iso6392Map)
                else
                  const _EmptyCard(),
              ],
            ),
            const SizedBox(height: 28),
            _buildSection(
              context,
              title: '音频',
              children: [
                if (audioStreams.isEmpty)
                  const _EmptyCard()
                else
                  ...audioStreams.map((s) => _AudioTrackCard(
                      stream: s,
                      iso6391Map: iso6391Map,
                      iso6392Map: iso6392Map)),
              ],
            ),
            const SizedBox(height: 28),
            _buildSection(
              context,
              title: '字幕',
              children: [
                if (subtitleStreams.isEmpty)
                  const _EmptyCard()
                else
                  ...subtitleStreams.map(
                    (s) => _SubtitleTrackCard(
                      stream: s,
                      iso6391Map: iso6391Map,
                      iso6392Map: iso6392Map,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FluentTheme.of(context).typography.subtitle?.copyWith(
                color: _textColor0,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

/// 空状态占位卡片（与网页一致：200px 高居中）。
class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FileMediaInfoDialog._cardSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '暂无数据',
        style: TextStyle(color: FileMediaInfoDialog._textColor1),
      ),
    );
  }
}

class _Field {
  const _Field(this.label, this.value);
  final String label;
  final String value;
}

String _dash(String v) => v.isEmpty ? '--' : v;

/// 单张轨道卡片：三列"标签:值"列表，列间用竖向分隔线隔开。
class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.heading, required this.columns});

  final String heading;

  /// 三列，每列是一组 (label, value)。
  final List<List<_Field>> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: FileMediaInfoDialog._cardSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading.isNotEmpty) ...[
            Text(
              heading,
              style: const TextStyle(
                color: FileMediaInfoDialog._textColor0,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const _VerticalDivider(),
                Expanded(child: _column(columns[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _column(List<_Field> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in fields)
          Row(
            children: [
              // 标签固定为内容宽度（对应 web 的 w-fit shrink-0），不参与弹性分配，
              // 这样值的 Expanded 才能占满剩余宽度并右对齐到列右缘。
              Text(
                f.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: FileMediaInfoDialog._textColor1,
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: f.value,
                  child: Text(
                    f.value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: FileMediaInfoDialog._textColor1,
                      fontSize: 12,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: FileMediaInfoDialog._dividerColor,
    );
  }
}

class _VideoTrackCard extends StatelessWidget {
  const _VideoTrackCard({
    required this.stream,
    required this.iso6391Map,
    required this.iso6392Map,
  });
  final VideoStream stream;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;

  @override
  Widget build(BuildContext context) {
    final heading = [
      stream.resolutionType,
      stream.codecName.toUpperCase(),
      stream.colorRangeType,
    ].where((s) => s.isNotEmpty).join(' ');
    final resolution =
        '${stream.width > 0 ? stream.width : stream.codedWidth} x '
        '${stream.height > 0 ? stream.height : stream.codedHeight}';
    return _TrackCard(
      heading: heading,
      columns: [
        [
          _Field('编码器', _dash(stream.codecName.toUpperCase())),
          _Field('配置', _dash(stream.profile)),
          _Field('等级', _dash(stream.level)),
          _Field('分辨率', _dash(resolution)),
          _Field('宽高比', _dash(stream.displayAspectRatio)),
        ],
        [
          _Field('隔行扫描', stream.progressive == 1 ? '否' : '是'),
          _Field('帧率', _dash(stream.rFrameRate)),
          _Field('码率', FnDataConvertor.formatBitrate(stream.bps)),
          _Field('视频动态范围', _dash(stream.colorRangeType)),
          _Field('色彩原色', _dash(stream.colorPrimaries)),
        ],
        [
          _Field('色彩空间', _dash(stream.colorSpace)),
          _Field('色彩转换', _dash(stream.colorTransfer)),
          _Field('位深度', stream.bitDepth > 0 ? '${stream.bitDepth} bit' : '--'),
          _Field('像素格式', _dash(stream.pixFmt)),
          _Field('参考帧', stream.refs.toString()),
        ],
      ],
    );
  }
}

class _AudioTrackCard extends StatelessWidget {
  const _AudioTrackCard({
    required this.stream,
    required this.iso6391Map,
    required this.iso6392Map,
  });
  final AudioStream stream;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;

  String _language() =>
      FnDataConvertor.getLanguageName(stream.language, iso6391Map, iso6392Map);

  String _codec() => stream.audioType.isNotEmpty
      ? stream.audioType
      : stream.codecName.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final heading = [
      _language(),
      _codec(),
      stream.channelLayout,
    ].where((s) => s.isNotEmpty).join(' ');
    return _TrackCard(
      heading: heading,
      columns: [
        [
          _Field('语言', _dash(_language())),
          _Field('编码器', _dash(_codec())),
          _Field('配置', _dash(stream.profile)),
        ],
        [
          _Field('布局', _dash(stream.channelLayout)),
          _Field('声道', stream.channels > 0 ? '${stream.channels} ch' : '--'),
          _Field('采样率',
              stream.sampleRate.isNotEmpty ? '${stream.sampleRate} Hz' : '--'),
        ],
        [
          _Field('码率', FnDataConvertor.formatBitrate(stream.bps)),
          _Field('默认', stream.isDefault == 1 ? '是' : '否'),
        ],
      ],
    );
  }
}

class _SubtitleTrackCard extends StatelessWidget {
  const _SubtitleTrackCard({
    required this.stream,
    required this.iso6391Map,
    required this.iso6392Map,
  });
  final SubtitleStream stream;
  final Map<String, String> iso6391Map;
  final Map<String, String> iso6392Map;

  String _language() =>
      FnDataConvertor.getLanguageName(stream.language, iso6391Map, iso6392Map);

  String _codec() =>
      stream.codecName.isNotEmpty ? stream.codecName : stream.codecType;

  @override
  Widget build(BuildContext context) {
    final heading = [
      _language(),
      _codec(),
    ].where((s) => s.isNotEmpty).join(' · ');
    return _TrackCard(
      heading: heading,
      columns: [
        [
          _Field('语言', _dash(_language())),
          _Field('编码器', _dash(_codec())),
        ],
        [
          _Field('默认', stream.isDefault == 1 ? '是' : '否'),
          _Field('强制', stream.forced == 1 ? '是' : '否'),
        ],
        [
          _Field('外部', stream.isExternal == 1 ? '是' : '否'),
        ],
      ],
    );
  }
}
