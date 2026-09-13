import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/widgets/playback_details_overlay.dart';

MediaTranscodeResponse _transcodeStatus() {
  return MediaTranscodeResponse(
    audio: MediaTranscodeAudio(channels: 2, encoder: 'AAC'),
    bitrate: 20000000,
    reqId: 'test',
    resolution: '1920 x 802',
    result: 'succ',
    transcoded: true,
    transcodingReason: [1, 5],
    video: MediaTranscodeVideo(
      corruptedFrames: 0,
      decodeMethod: 2,
      droppedFrames: 0,
      dynamicRange: 'HDR10',
      encodeMethod: 2,
      encoder: 'HEVC',
      selectedGpu: 'GPU 1 – Intel',
      transcodingRate: '385 fps',
    ),
  );
}

void main() {
  testWidgets('transcode panel renders two-column playback info', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FluentApp(
        home: Align(
            alignment: Alignment.center,
            child: PlaybackDetailsPanel(
              cache: const PlayingInfoCache(isUseDirectLink: false),
              transcodeStatus: _transcodeStatus(),
              bufferedSeconds: 30.95,
            ),
          ),
      ),
    );
    await tester.pumpAndSettle();

    // Header: play type and transcoding reasons.
    expect(find.text('播放类型： 转码播放'), findsOneWidget);
    expect(
      find.text(
        '转码原因： 根据视频质量设置降低画质；音频格式转换',
      ),
      findsOneWidget,
    );

    // Left column.
    expect(find.text('缓冲时长： 30.95 s'), findsOneWidget);
    expect(find.text('分辨率： 1920 x 802'), findsOneWidget);
    expect(find.text('码率： 20 Mbps'), findsOneWidget);
    expect(find.text('编码器： HEVC'), findsOneWidget);
    expect(find.text('视频动态范围： HDR10'), findsOneWidget);
    expect(find.text('音频编码： AAC'), findsOneWidget);
    expect(find.text('声道： 2'), findsOneWidget);

    // Right column.
    expect(find.text('启用 GPU： GPU 1 – Intel'), findsOneWidget);
    expect(find.text('解码方式： VAAPI 解码'), findsOneWidget);
    expect(find.text('编码方式： QSV 低电压编码'), findsOneWidget);
    expect(find.text('转码帧率： 385 fps'), findsOneWidget);
    expect(find.text('丢帧： 0'), findsOneWidget);
    expect(find.text('坏帧： 0'), findsOneWidget);

    // The two columns sit side by side instead of stacking vertically.
    final leftTop = tester.getTopLeft(find.text('缓冲时长： 30.95 s'));
    final rightTop = tester.getTopLeft(find.text('启用 GPU： GPU 1 – Intel'));
    expect(rightTop.dx, greaterThan(leftTop.dx + 100));
    expect((rightTop.dy - leftTop.dy).abs(), lessThan(40));
  });

  testWidgets('direct play panel hides playback info section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FluentApp(
        home: Align(
            alignment: Alignment.center,
            child: PlaybackDetailsPanel(
              cache: const PlayingInfoCache(),
            ),
          ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('播放类型： 直接播放'), findsOneWidget);
    expect(find.text('播放信息'), findsNothing);
    expect(find.text('媒体源信息'), findsOneWidget);
  });
}
