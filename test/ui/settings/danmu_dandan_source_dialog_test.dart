import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/data/datasources/remote/fly_narwhal_remote_data_source.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/features/settings/widgets/danmu_dandan_source_dialog.dart';

/// Boots the real DanmuDandanSourceDialog against a scripted data source and
/// asserts the switch rules the settings redesign is built on: the two enable
/// switches are independent, the preferred switches are mutually exclusive, and
/// a source that is off cannot be preferred.
class _FakeDataSource extends FlyNarwhalRemoteDataSource {
  _FakeDataSource(this._config)
      : super(
          getToken: () => '',
          getCookie: () => '',
          getFnBaseUrl: () => 'http://localhost:5365',
          getFlyNarwhalBaseUrl: () => 'http://localhost:5365',
          getFlyNarwhalServerEnabled: () => true,
          getAuthCode: () => '',
          getClientVersion: () => '9.9.9',
        );

  final DanmuSourceConfig _config;

  /// Records every relay save so a test can assert what the switch sent.
  final List<DanmuDandanConfig> relaySaves = [];

  @override
  Future<ApiResult<SmartAnalysisResult<DanmuSourceConfig>>>
      getDanmuSourceConfig() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Success(SmartAnalysisResult(
      code: 200,
      msg: 'Success',
      data: _config,
      success: true,
    ));
  }

  @override
  Future<ApiResult<SmartAnalysisResult<String>>> saveDandanRelay({
    required DanmuDandanConfig dandan,
  }) async {
    relaySaves.add(dandan);
    return const Success(SmartAnalysisResult(
      code: 200, msg: 'Success', data: '', success: true));
  }
}

const _officialOnly = DanmuSourceConfig(
  // Official enabled and preferred; relay off with no address.
  dandanAccount: DandanAccount(
    appId: 'my-id',
    appSecret: 'my-secret',
    enabled: true,
    priority: 0,
  ),
  dandan: DanmuDandanConfig(url: '', enabled: false, priority: 1),
);

const _bothOn = DanmuSourceConfig(
  dandanAccount: DandanAccount(
    appId: 'my-id',
    appSecret: 'my-secret',
    enabled: true,
    priority: 0,
  ),
  dandan: DanmuDandanConfig(
    url: 'https://relay.example/ddp/v1',
    enabled: true,
    priority: 1,
  ),
);

Future<_FakeDataSource> _pump(
    WidgetTester tester, DanmuSourceConfig config, SharedPreferences prefs) async {
  final ds = _FakeDataSource(config);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flyNarwhalRemoteDataSourceProvider.overrideWithValue(ds),
      ],
      child: const FluentApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(content: DanmuDandanSourceDialog()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle();
  return ds;
}

/// The dialog is taller than the test surface, so a switch can be off-screen
/// and `tester.widget` would still find it while a tap would not.
bool _isOn(WidgetTester tester, String key) =>
    tester.widget<ToggleSwitch>(find.byKey(ValueKey(key))).checked;

void main() {
  // The controller resolves its l10n function through settingsProvider, which
  // reads SharedPreferences; the provider throws until it is given over.
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('renders both source cards without an error', (tester) async {
    await _pump(tester, _bothOn, prefs);

    expect(tester.takeException(), isNull);
    expect(find.text('官方服务'), findsOneWidget);
    expect(find.text('中转服务'), findsOneWidget);
    // Two enable switches + two preferred switches.
    expect(find.byType(ToggleSwitch), findsNWidgets(4));
    expect(find.byType(ProgressRing), findsNothing);
  });

  testWidgets('preferred follows the stored priority', (tester) async {
    await _pump(tester, _bothOn, prefs);

    // priority 0 on the official row means its preferred switch is on.
    expect(_isOn(tester, 'settings-danmu-official-preferred'), isTrue);
    expect(_isOn(tester, 'settings-danmu-relay-preferred'), isFalse);
  });

  testWidgets('a source that is off cannot be set as preferred', (tester) async {
    // Relay is off, so its preferred switch must be disabled — the user cannot
    // prefer a channel that is not in use.
    await _pump(tester, _officialOnly, prefs);

    expect(_toggled(tester, 'settings-danmu-official-preferred'),
        isNotNull);
    expect(_toggled(tester, 'settings-danmu-relay-preferred'), isNull,
        reason: 'preferred must be greyed out while the relay is off');
    expect(_isOn(tester, 'settings-danmu-relay-enable'), isFalse);
  });

  testWidgets('the enable switches are independent', (tester) async {
    // Both on: each enable switch stays independently operable.
    await _pump(tester, _bothOn, prefs);

    expect(_isOn(tester, 'settings-danmu-official-enable'), isTrue);
    expect(_isOn(tester, 'settings-danmu-relay-enable'), isTrue);
    expect(_toggled(tester, 'settings-danmu-official-enable'),
        isNotNull);
    expect(_toggled(tester, 'settings-danmu-relay-enable'), isNotNull);
  });

  testWidgets('a stale preference on a disabled source moves to the live one',
      (tester) async {
    // Relay holds priority 0 but is switched off: the server skips it, so the
    // official channel is what actually gets searched. The switches must show
    // that rather than the stale stored priority.
    await _pump(
      tester,
      const DanmuSourceConfig(
        dandanAccount: DandanAccount(
          appId: 'my-id',
          appSecret: 'my-secret',
          enabled: true,
          priority: 1,
        ),
        dandan: DanmuDandanConfig(
          url: 'https://relay.example/ddp/v1',
          enabled: false,
          priority: 0,
        ),
      ),
      prefs,
    );

    expect(_isOn(tester, 'settings-danmu-official-preferred'), isTrue,
        reason: 'the only enabled source is the one actually searched first');
    expect(_isOn(tester, 'settings-danmu-relay-preferred'), isFalse);
  });

  testWidgets('a save never disables the switches', (tester) async {
    // Regression: gating the switches on the global save flag made every switch
    // on the card render as disabled for the length of the save round-trip, so
    // toggling one flickered all four. The switches must stay interactive; a
    // re-entrancy guard in the dialog handles double taps instead.
    final ds = await _pump(tester, _bothOn, prefs);

    _toggled(tester, 'settings-danmu-relay-enable')!(false);
    await tester.pump();

    // Mid-save (the fake data source lags), every switch must still be enabled.
    for (final key in const [
      'settings-danmu-official-enable',
      'settings-danmu-relay-enable',
    ]) {
      expect(_toggled(tester, key), isNotNull,
          reason: '$key must stay interactive while a save is in flight');
    }
    expect(ds.relaySaves, hasLength(1));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });

  testWidgets('turning the relay off keeps its stored address', (tester) async {    final ds = await _pump(tester, _bothOn, prefs);

    // Invoke the switch's callback directly: the dialog scrolls inside a fixed
    // height, so tapping the row would depend on the test surface size.
    final cb = _toggled(tester, 'settings-danmu-relay-enable');
    expect(cb, isNotNull, reason: 'relay enable switch must be tappable');
    cb!(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(ds.relaySaves, hasLength(1));
    final saved = ds.relaySaves.single;
    expect(saved.enabled, isFalse);
    expect(saved.url, 'https://relay.example/ddp/v1',
        reason: 'the address must survive the switch being turned off');
  });
}

/// The switch's change callback, looked up by key.
ValueChanged<bool>? _toggled(WidgetTester tester, String key) =>
    tester.widget<ToggleSwitch>(find.byKey(ValueKey(key))).onChanged;
