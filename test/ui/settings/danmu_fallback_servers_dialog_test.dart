import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/features/settings/widgets/danmu_fallback_servers_dialog.dart';

/// Boots the real DanmuFallbackServersDialog with a scripted data source and
/// asserts the list renders once the config load resolves — a regression
/// guard for the "stuck spinner" report.
class _FakeDataSource extends FlyNarwhalRemoteDataSource {
  _FakeDataSource()
      : super(
          getToken: () => '',
          getCookie: () => '',
          getFnBaseUrl: () => 'http://localhost:5365',
          getFlyNarwhalBaseUrl: () => 'http://localhost:5365',
          getFlyNarwhalServerEnabled: () => true,
          getAuthCode: () => '',
          getClientVersion: () => '9.9.9',
        );

  @override
  Future<ApiResult<SmartAnalysisResult<DanmuSourceConfig>>>
      getDanmuSourceConfig() async {
    // A tick of latency so the dialog's initial build sees AsyncLoading,
    // exactly like the production report.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    const config = DanmuSourceConfig(
      dandan: DanmuDandanConfig(
        url: 'https://api.danmaku.weeblify.app/ddp/v1',
        enabled: true,
      ),
      fallbackServers: [
        DanmuFallbackServer(
          id: 2,
          name: 'dmku',
          url: 'https://dmku.hls.one',
          enabled: true,
        ),
      ],
    );
    return const Success(SmartAnalysisResult(
      code: 200,
      msg: 'Success',
      data: config,
      success: true,
    ));
  }
}

void main() {
  testWidgets('dialog renders the server list after the load resolves',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flyNarwhalRemoteDataSourceProvider
              .overrideWithValue(_FakeDataSource()),
        ],
        child: const FluentApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScaffoldPage(content: DanmuFallbackServersDialog()),
        ),
      ),
    );
    // The load starts synchronously in initState; the scripted response
    // resolves 50ms later.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('dmku'), findsOneWidget);
    expect(find.byType(ToggleSwitch), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
  });
}
