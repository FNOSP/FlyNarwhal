import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/data/models/movie_detail_models.dart';
import 'package:fly_narwhal/ui/shared/dialogs/file_media_info_dialog.dart';

VideoStream _video() => VideoStream.fromJson({
      'media_guid': 'm1',
      'title': 'video',
      'guid': 'v1',
      'resolution_type': '1080p',
      'color_range_type': 'SDR',
      'codec_name': 'h264',
      'codec_type': 'video',
      'color_range': 'tv',
      'profile': 'High',
      'index': 0,
      'width': 1920,
      'height': 800,
      'coded_width': 1920,
      'coded_height': 800,
      'display_aspect_ratio': '12:5',
      'pix_fmt': 'yuv420p',
      'level': '41',
      'color_space': 'bt709',
      'color_transfer': 'bt709',
      'color_primaries': 'bt709',
      'duration': 0,
      'dv_profile': 0,
      'refs': 4,
      'r_frame_rate': '23.98 fps',
      'avg_frame_rate': '23.98 fps',
      'bits_per_raw_sample': '',
      'bps': 18850000,
      'progressive': 1,
      'bit_depth': 8,
      'wrapper': 'mkv',
      'create_time': 0,
      'update_time': 0,
      'rotation': 0,
      'ext1': 0,
      'is_bluray': false,
    });

AudioStream _audio() => AudioStream.fromJson({
      'media_guid': 'm1',
      'title': 'audio',
      'guid': 'a1',
      'audio_type': 'DTS',
      'codec_name': 'dca',
      'codec_type': 'audio',
      'language': 'eng',
      'channels': 8,
      'profile': 'MA',
      'sample_rate': '48000',
      'is_default': 1,
      'channel_layout': '7.1',
      'duration': 0,
      'index': 1,
      'bits_per_raw_sample': '',
      'bps': 768000,
      'create_time': 0,
      'update_time': 0,
      'is_fake': false,
    });

SubtitleStream _subtitle() => SubtitleStream.fromJson({
      'media_guid': 'm1',
      'title': 'sub',
      'guid': 's1',
      'codec_name': 'ass',
      'codec_type': 'subtitle',
      'language': 'chi',
      'forced': 0,
      'index': 2,
      'is_default': 1,
      'is_external': 0,
      'format': 'ass',
      'trim_id': '',
      'source_id': '',
      'Source': '',
      'create_time': 0,
      'update_time': 0,
      'extra_file': 0,
      'is_bitmap': 0,
      'file_size': 0,
    });

void main() {
  testWidgets('media info dialog renders three columns without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FluentApp(
        home: Builder(
          builder: (context) => ScaffoldPage(
            content: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => FileMediaInfoDialog(
                    videoStream: _video(),
                    audioStreams: [_audio()],
                    subtitleStreams: [_subtitle()],
                    iso6391Map: const {},
                    iso6392Map: const {'eng': '英语', 'chi': '中文'},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('文件媒体信息'), findsOneWidget);
    expect(find.text('1080p H264 SDR'), findsOneWidget);
    expect(find.text('英语 DTS 7.1'), findsOneWidget); // 音频标题 = 语言+编码+布局
    expect(find.text('中文 · ass'), findsOneWidget); // 字幕标题

    // 三列字段都渲染出来。
    expect(find.text('编码器'), findsWidgets);
    expect(find.text('色彩空间'), findsOneWidget);
    expect(find.text('采样率'), findsOneWidget);
    expect(find.text('外部'), findsOneWidget);
    expect(find.text('H264'), findsWidgets);
    expect(find.text('48000 Hz'), findsOneWidget);

    // 三列横向并排（值右对齐），第二列位于第一列右侧。
    final encoderLeft = tester.getTopLeft(find.text('编码器').first);
    final colorSpaceLeft = tester.getTopLeft(find.text('色彩空间'));
    expect(colorSpaceLeft.dx, greaterThan(encoderLeft.dx + 150));

    // 值须右对齐到各自列的右缘（紧贴分隔线左侧，间距≈41px），而非悬浮在列中间。
    final h264Right = tester.getRect(find.text('H264').first).right;
    final col2LabelLeft = tester.getRect(find.text('隔行扫描').first).left;
    expect((col2LabelLeft - h264Right).abs(), lessThan(60),
        reason: 'col1 value should hug the divider on its right');

    // 无任何 RenderFlex 溢出。
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state shows the web-matching illustration for any track', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FluentApp(
        home: Builder(
          builder: (context) => ScaffoldPage(
            content: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => FileMediaInfoDialog(
                    videoStream: null,
                    audioStreams: const [],
                    subtitleStreams: const [],
                    iso6391Map: const {},
                    iso6392Map: const {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.text('暂无数据'), findsNothing);
    expect(
      find.byType(Image),
      findsNWidgets(3),
      reason: 'all empty tracks should show the placeholder illustration',
    );
    expect(tester.takeException(), isNull);
  });
}
