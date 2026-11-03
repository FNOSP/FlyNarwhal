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

/// The FlyNarwhal server, mocked at the data-source boundary.
class _FakeServer extends FlyNarwhalRemoteDataSource {
  _FakeServer({required this.version})
      : super(
          getToken: () => '',
          getCookie: () => '',
          getFnBaseUrl: () => '',
          getFlyNarwhalBaseUrl: () => '',
          getAuthCode: () => '',
        );

  /// Null makes the lookup fail the way an unreachable server does.
  final String? version;
  int versionCalls = 0;

  @override
  Future<ApiResult<SmartAnalysisResult<String>>> getVersion({
    String? baseUrl,
  }) async {
    versionCalls++;
    final value = version;
    if (value == null) {
      return ResultFailure(FailureInfo.fromMessage('飞鲸服务端无法访问'));
    }
    return Success(SmartAnalysisResult<String>(code: 0, msg: 'ok', data: value));
  }
}

/// Answers api.github.com's `/releases/latest` without any network, and
/// records the URLs asked for.
class _FakeGitHub implements Interceptor {
  _FakeGitHub(this.tagName);

  final String tagName;
  final List<String> requestedUrls = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestedUrls.add(options.uri.toString());
    if (!options.uri.path.endsWith('/releases/latest')) {
      handler.next(options);
      return;
    }
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: {'tag_name': tagName, 'assets': <Object>[]},
      ),
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) =>
      handler.next(response);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) =>
      handler.next(err);
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> seedConfiguredServer() async {
    await prefs.setBool('fly_narwhal_server_enabled', true);
    await prefs.setString(
      'fly_narwhal_server_base_url',
      'http://192.168.1.1:5365',
    );
    await prefs.setString('fly_narwhal_server_auth_code', 'FN1_TEST');
  }

  Future<void> pumpSettings(
    WidgetTester tester,
    _FakeServer server,
    _FakeGitHub github,
  ) async {
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flyNarwhalRemoteDataSourceProvider.overrideWithValue(server),
        flyNarwhalServerReleaseDataSourceProvider.overrideWithValue(
          FlyNarwhalServerReleaseDataSource(
            dio: Dio()..interceptors.add(github),
            userAgent: 'test',
          ),
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
  }

  /// The toast texts the page actually queued after entering.
  List<String> toasts() =>
      container.read(toastManagerProvider).map((t) => t.message).toList();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('a current server shows no toast', (tester) async {
    await seedConfiguredServer();
    final server = _FakeServer(version: '2.1.2');
    final github = _FakeGitHub('v2.1.2');
    await pumpSettings(tester, server, github);
    await tester.pumpAndSettle();

    expect(server.versionCalls, greaterThan(0));
    expect(
      github.requestedUrls.where((u) => u.contains('/releases/latest')),
      hasLength(1),
    );
    expect(toasts(), isEmpty);
  });

  testWidgets('an unreachable server toasts the failure', (tester) async {
    await seedConfiguredServer();
    final server = _FakeServer(version: null);
    await pumpSettings(tester, server, _FakeGitHub('v2.1.2'));
    await tester.pumpAndSettle();

    expect(server.versionCalls, greaterThan(0));
    expect(toasts().join('\n'), contains('获取飞鲸服务端版本失败'));
    expect(toasts().join('\n'), contains('飞鲸服务端无法访问'));
  });

  testWidgets('a server without a version toasts that instead', (tester) async {
    await seedConfiguredServer();
    await pumpSettings(tester, _FakeServer(version: ''), _FakeGitHub('v2.1.2'));
    await tester.pumpAndSettle();

    final messages = toasts().join('\n');
    expect(messages, contains('获取飞鲸服务端版本失败'));
    expect(messages, contains('未返回版本号'));
  });

  testWidgets('a newer server release is announced once', (tester) async {
    await seedConfiguredServer();
    await pumpSettings(tester, _FakeServer(version: '2.1.2'), _FakeGitHub('v2.1.3'));
    await tester.pumpAndSettle();

    final messages = toasts();
    expect(
      messages.where((m) => m.contains('2.1.3')).length,
      1,
      reason: 'toasts: $messages',
    );
    expect(messages.single, contains('飞牛应用中心'));
  });

  testWidgets('the release tag prefix does not fool the comparison',
      (tester) async {
    await seedConfiguredServer();
    // A server on a build suffix is still current when only the base version
    // differs; v-prefixed tags must compare numerically.
    await pumpSettings(
      tester,
      _FakeServer(version: '2.1.2-fnapp'),
      _FakeGitHub('v2.1.2'),
    );
    await tester.pumpAndSettle();

    expect(toasts(), isEmpty);
  });
}
