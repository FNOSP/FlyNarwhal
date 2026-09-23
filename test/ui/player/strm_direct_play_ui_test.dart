import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/tooling/driver_test_mode.dart';
import 'package:fly_narwhal/ui/features/player/widgets/cloud_playback_widgets.dart';
import 'package:fly_narwhal/ui/features/player/widgets/playback_details_overlay.dart';
import 'package:fly_narwhal/ui/features/player/widgets/quality_control_flyout.dart';
import 'package:fly_narwhal/ui/features/player/widgets/strm_play_tips_flyout.dart';

void main() {
  setUpAll(() {
    // Flyouts toggle on tap and use a long hide delay in driver test mode.
    kDriverTestMode = true;
  });

  group('StrmPlayTipsFlyout', () {
    testWidgets(
      'Given STRM media, When tapping the cloud icon, Then the direct-play tip is shown',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.bottomCenter,
              child: StrmPlayTipsFlyout(
                key: const ValueKey('strm-tips-under-test'),
              ),
            ),
          ),
        );

        expect(find.text('正在直连播放 STRM 文件'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('strm-tips-under-test')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('正在直连播放 STRM 文件'), findsOneWidget);
      },
    );

    testWidgets(
      'Given an open tip, When tapping the cloud icon again, Then the tip closes',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.bottomCenter,
              child: StrmPlayTipsFlyout(
                key: const ValueKey('strm-tips-under-test'),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('strm-tips-under-test')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('正在直连播放 STRM 文件'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('strm-tips-under-test')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('正在直连播放 STRM 文件'), findsNothing);
      },
    );
  });

  group('PlaybackDetailsPanel play type label', () {
    testWidgets(
      'Given an STRM direct-link session, Then the play type reads STRM 直连播放',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.center,
              child: PlaybackDetailsPanel(
                cache: PlayingInfoCache(
                  isUseDirectLink: true,
                  streamInfo: StreamResponse(
                    cloudStorageInfo: CloudStorageInfo(
                      cloudStorageType: CloudStorageInfo.strmCloudStorageType,
                      cloudNickName: 'strm文件',
                    ),
                    directLinkQualities: [
                      DirectLinkQuality(resolution: '原画'),
                    ],
                  ),
                ),
                bufferedSeconds: 0,
              ),
            ),
          ),
        );

        expect(find.text('播放类型： STRM 直连播放'), findsOneWidget);
        expect(find.text('播放类型： 网盘直连播放'), findsNothing);
      },
    );

    testWidgets(
      'Given a cloud-drive direct-link session, Then the play type still reads 网盘直连播放',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.center,
              child: PlaybackDetailsPanel(
                cache: PlayingInfoCache(
                  isUseDirectLink: true,
                  streamInfo: StreamResponse(
                    cloudStorageInfo: CloudStorageInfo(cloudStorageType: 4),
                    directLinkQualities: [
                      DirectLinkQuality(resolution: '原画'),
                    ],
                  ),
                ),
                bufferedSeconds: 0,
              ),
            ),
          ),
        );

        expect(find.text('播放类型： 网盘直连播放'), findsOneWidget);
        expect(find.text('播放类型： STRM 直连播放'), findsNothing);
      },
    );
  });

  group('QualityControlFlyout cloud hint', () {
    final qualities = [
      QualityResponse(bitrate: 0, resolution: '原画'),
    ];

    testWidgets(
      'Given STRM media, Then the 原画无声音 hint is hidden',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.bottomCenter,
              child: QualityControlFlyout(
                key: const ValueKey('quality-under-test'),
                qualities: qualities,
                currentResolution: '原画',
                cloudMode: true,
                isStrm: true,
                onQualitySelected: (_) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('quality-under-test')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('视频质量'), findsOneWidget);
        expect(find.text('直连播放原画无声音'), findsNothing);
      },
    );

    testWidgets(
      'Given non-STRM cloud media, Then the 原画无声音 hint is still shown',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            home: Align(
              alignment: Alignment.bottomCenter,
              child: QualityControlFlyout(
                key: const ValueKey('quality-under-test'),
                qualities: qualities,
                currentResolution: '原画',
                cloudMode: true,
                onQualitySelected: (_) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('quality-under-test')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('直连播放原画无声音'), findsOneWidget);
      },
    );
  });

  group('CloudPlaybackErrorDialog STRM variant', () {
    Widget buildDialog({required bool isStrm}) {
      return FluentApp(
        home: Stack(
          children: [
            CloudPlaybackErrorDialog(
              isStrm: isStrm,
              onRetry: () {},
              onSwitchQuality: () {},
              onSwitchProxy: () {},
              onSwitchDirect: () {},
              onBack: () {},
            ),
          ],
        ),
      );
    }

    testWidgets(
      'Given STRM media, Then the error page shows the STRM cause hint and only 返回 / 重试',
      (tester) async {
        await tester.pumpWidget(buildDialog(isStrm: true));

        expect(
          find.text(
            'STRM 直连播放异常，可能原因：网盘挂载连接断开、触发网盘风控、'
            '网盘限制非会员操作、浏览器不支持该文件类型。',
          ),
          findsOneWidget,
        );
        expect(find.text('抱歉，播放出错了'), findsNothing);
        expect(find.text('返回'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('播放其他画质'), findsNothing);
        expect(find.text('切换 NAS 代理播放'), findsNothing);
        expect(find.text('网盘直连播放'), findsNothing);
      },
    );

    testWidgets(
      'Given non-STRM media, Then the error page keeps the generic message and mode buttons',
      (tester) async {
        await tester.pumpWidget(buildDialog(isStrm: false));

        expect(find.text('抱歉，播放出错了'), findsOneWidget);
        expect(find.textContaining('STRM 直连播放异常'), findsNothing);
        expect(find.text('返回'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('播放其他画质'), findsOneWidget);
        expect(find.text('切换 NAS 代理播放'), findsOneWidget);
      },
    );
  });
}
