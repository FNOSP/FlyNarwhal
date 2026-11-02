import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/features/settings/widgets/danmu_fallback_servers_dialog.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Answers every save with the server's own wording for a host-less address,
/// so the client-side validation and the error-localization path can both be
/// exercised end to end.
class _RejectingDataSource extends _FakeDataSource {
  static const serverReason = 'url host is invalid';

  int saveCalls = 0;

  @override
  Future<ApiResult<SmartAnalysisResult<String>>> saveFallbackServer({
    required DanmuFallbackServer server,
  }) async {
    saveCalls++;
    return const Success(SmartAnalysisResult(
      code: 500,
      msg: serverReason,
      data: null,
      success: false,
    ));
  }
}

/// The primary button of the editor sub-dialog.
///
/// Once the editor is open both dialogs are mounted, and the button key sits
/// twice per dialog (on `AppFilledButton` and the `FilledButton` it wraps), so
/// the four candidates run list-then-editor. The editor's own button is the
/// third; this is only called while the editor is open.
Finder _editorSaveButton() =>
    find.byKey(const ValueKey('app-dialog-primary')).at(2);

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<void> _pumpDialog(
    WidgetTester tester, _FakeDataSource dataSource, SharedPreferences prefs) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flyNarwhalRemoteDataSourceProvider.overrideWithValue(dataSource),
      ],
      child: const FluentApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(content: DanmuFallbackServersDialog()),
      ),
    ),
  );
}

/// Loads the list, then opens the add-server sub-dialog.
Future<void> _openEditor(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加服务器'));
  await tester.pumpAndSettle();
}

Finder get _urlField =>
    find.byKey(const ValueKey('settings-danmu-fallback-url-input'));

/// Invokes the editor's save action. Tapping the nested dialog is unreliable
/// in widget tests, so the button's own callback is invoked directly.
Future<void> _tapSave(WidgetTester tester) async {
  tester.widget<AppFilledButton>(_editorSaveButton()).onPressed!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog renders the server list after the load resolves',
      (tester) async {
    await _pumpDialog(tester, _FakeDataSource(), await _prefs());
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

  /// Addresses the server would reject with "url host is invalid" must be
  /// caught in the dialog — no request leaves the client.
  testWidgets('a host-less address is rejected before it reaches the server',
      (tester) async {
    final dataSource = _RejectingDataSource();
    await _pumpDialog(tester, dataSource, await _prefs());
    await _openEditor(tester);

    expect(_urlField, findsOneWidget);
    for (final rejected in ['http://', 'not-a-url']) {
      await tester.enterText(_urlField, rejected);
      await tester.pumpAndSettle();
      await _tapSave(tester);
      expect(
        dataSource.saveCalls,
        0,
        reason: '"$rejected" must be blocked client-side',
      );
    }
  });

  /// A valid address does reach the server, and its English reason is never
  /// shown raw — the controller maps it to the user's language.
  testWidgets('a server rejection is localized instead of shown verbatim',
      (tester) async {
    final dataSource = _RejectingDataSource();
    await _pumpDialog(tester, dataSource, await _prefs());
    await _openEditor(tester);

    await tester.enterText(_urlField, 'https://example.invalid');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(dataSource.saveCalls, 1);
    expect(find.text(_RejectingDataSource.serverReason), findsNothing);
    expect(tester.takeException(), isNull);
  });
}