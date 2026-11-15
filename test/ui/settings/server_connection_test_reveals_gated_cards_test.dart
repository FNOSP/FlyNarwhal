import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_server_release_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/providers/update_providers.dart';
import 'package:fly_narwhal/ui/features/settings/settings_screen.dart';
import 'package:fly_narwhal/ui/shared/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The FlyNarwhal server, mocked at the data-source boundary. [version] is
/// mutable so a test can simulate the server being upgraded while the client
/// keeps running.
class _FakeServer extends FlyNarwhalRemoteDataSource {
  _FakeServer({required this.version})
      : super(
          getToken: () => '',
          getCookie: () => '',
          getFnBaseUrl: () => '',
          getFlyNarwhalBaseUrl: () => '',
          getAuthCode: () => '',
        );

  String version;
  int versionCalls = 0;

  @override
  Future<ApiResult<SmartAnalysisResult<String>>> getVersion({
    String? baseUrl,
  }) async {
    versionCalls++;
    return Success(
      SmartAnalysisResult<String>(code: 0, msg: 'ok', data: version),
    );
  }
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> seedConfiguredServer(String baseUrl) async {
    await prefs.setBool('fly_narwhal_server_enabled', true);
    await prefs.setString('fly_narwhal_server_base_url', baseUrl);
    await prefs.setString('fly_narwhal_server_auth_code', 'FN1_TEST');
  }

  Future<void> pumpSettings(WidgetTester tester, _FakeServer server) async {
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flyNarwhalRemoteDataSourceProvider.overrideWithValue(server),
        flyNarwhalServerReleaseDataSourceProvider.overrideWithValue(
          FlyNarwhalServerReleaseDataSource(dio: Dio(), userAgent: 'test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...FluentLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Stack(children: [SettingsScreen(), ToastHost()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'Test re-probes and reveals the gated cards after an in-place server upgrade',
    (tester) async {
      // Regression test for probeFlyNarwhalServer bypassing
      // serverVersionProbeProvider: entering the page cached "legacy" for this
      // address, then the server was upgraded to 2.1.0 without the address or
      // auth code changing. Clicking "Test" must publish the fresh answer to
      // flyNarwhalServerCapabilitiesProvider — not just toast it — or the
      // 2.0.0/2.1.0-gated cards stay hidden even though the toast says 2.1.0.
      const baseUrl = 'http://192.168.31.73:5367';
      await seedConfiguredServer(baseUrl);
      final server = _FakeServer(version: '1.9.0');
      await pumpSettings(tester, server);

      expect(find.text('智能跳过配置'), findsNothing);

      server.version = '2.1.0';
      final testButton =
          find.byKey(const ValueKey('settings-fly-narwhal-test')).first;
      await tester.ensureVisible(testButton);
      await tester.pumpAndSettle();
      await tester.tap(testButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('飞鲸服务端连接成功，当前服务端版本号：2.1.0'),
        findsOneWidget,
      );
      expect(find.text('智能跳过配置'), findsOneWidget);
      expect(find.text('弹弹play 弹幕源'), findsOneWidget);
      expect(find.text('视频缩略图生成'), findsOneWidget);
    },
  );
}