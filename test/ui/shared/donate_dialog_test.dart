import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/providers.dart';
import 'package:fly_narwhal/ui/navigation/app_router.dart';
import 'package:fly_narwhal/ui/shared/celebration_overlay.dart';
import 'package:fly_narwhal/ui/shared/dialogs/app_dialog.dart';
import 'package:fly_narwhal/ui/features/settings/widgets/support_author_item.dart';

const _donateQrAsset = 'assets/images/donate_qr.jpg';
const _captureKey = ValueKey('capture-boundary');

/// Exposes a live [Ref] so tests can hand one to [SupportAuthorPromptObserver]
/// (WidgetRef from a Consumer is not assignable to Ref).
final _refProbeProvider = Provider<Ref<Object?>>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Serve real asset bytes (QR jpeg, the item's svg icon) through the test
    // asset bundle so Image.asset / SvgPicture resolve in the test env.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'AssetManifest.bin') {
        // StandardMessageCodec encoding of an empty map (typeMap=13, size=0).
        return ByteData.sublistView(Uint8List.fromList([13, 0]));
      }
      if (key == 'FontManifest.json') {
        return ByteData.sublistView(Uint8List.fromList(utf8.encode('[]')));
      }
      final file = File(key);
      if (file.existsSync()) {
        return ByteData.sublistView(file.readAsBytesSync());
      }
      return null;
    });
    final fontData =
        File('assets/fonts/SourceHanSansSC-VF.otf').readAsBytesSync();
    final fontLoader = FontLoader('SourceHanSansSC')
      ..addFont(
        Future.value(ByteData.sublistView(Uint8List.fromList(fontData))),
      );
    await fontLoader.load();
  });

  Future<SharedPreferences> pumpSupportAuthorItem(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: FluentApp(
            locale: const Locale('zh'),
            theme: FluentThemeData(fontFamily: 'SourceHanSansSC'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Center(
              child: SizedBox(width: 640, child: SupportAuthorItem()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> capturePng(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(data!.buffer.asUint8List());
    });
  }

  testWidgets('support dialog shows QR, donate copy and 我已赞赏 action',
      (tester) async {
    final prefs = await pumpSupportAuthorItem(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-support-author-button')).first,
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SupportAuthorItem)),
    );
    // The dialog title duplicates the settings button label, so scope the
    // text assertions to the dialog subtree.
    final dialog = find.byWidgetPredicate((widget) => widget is AppDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text(l10n.supportAuthorTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(l10n.supportAuthorDonate)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(l10n.supportAuthorDonated),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(l10n.supportAuthorOpenRepo),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(l10n.supportAuthorLater)),
      findsOneWidget,
    );

    // The QR image is present and points at the bundled asset.
    final image = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == _donateQrAsset,
      ),
    );
    expect(image, isNotNull);

    // Flush the async JPEG decode so the QR is painted into the capture.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await capturePng(tester, '/tmp/donate_dialog.png');

    // Confirming the donation marks the flag and triggers the celebration.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SupportAuthorItem)));
    expect(container.read(celebrationTriggerProvider), 0);

    await tester.tap(find.byKey(const ValueKey('app-dialog-primary')).first);
    await tester.pumpAndSettle();

    expect(prefs.getBool('donation_support_donated'), isTrue);
    expect(container.read(celebrationTriggerProvider), 1);
    expect(find.byWidgetPredicate((widget) => widget is AppDialog), findsNothing);
  });

  testWidgets('celebration overlay renders confetti and thanks sticker',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: FluentApp(
            locale: const Locale('zh'),
            theme: FluentThemeData(fontFamily: 'SourceHanSansSC'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox.expand(child: CelebrationOverlayHost()),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CelebrationOverlayHost)),
    );
    container.read(celebrationTriggerProvider.notifier).state++;
    await tester.pump(); // post-frame launch
    // The controller's first tick only establishes the time baseline, so pump
    // twice for the value to actually advance.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600)); // pop-in
    expect(find.text('谢谢老板'), findsOneWidget);
    await capturePng(tester, '/tmp/celebration_early.png');

    await tester.pump(const Duration(milliseconds: 700)); // confetti falling
    expect(find.text('谢谢老板'), findsOneWidget);
    await capturePng(tester, '/tmp/celebration_mid.png');

    // Fades out and becomes inert after the full duration.
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('谢谢老板'), findsNothing);
  });

  testWidgets('player exit with 3h+ watch time prompts dialog after 2s',
      (tester) async {
    SharedPreferences.setMockInitialValues({'watch_time_seconds': 11000});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserGuidProvider.overrideWithValue(null),
        ],
        child: Consumer(
          builder: (context, ref, _) => FluentApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorKey: rootNavigatorKey,
            navigatorObservers: [
              SupportAuthorPromptObserver(ref.read(_refProbeProvider)),
            ],
            home: Builder(
              builder: (context) => Button(
                key: const ValueKey('push-player'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    PageRouteBuilder<void>(
                      settings: const RouteSettings(name: '/player/:guid'),
                      pageBuilder: (_, __, ___) => const SizedBox.expand(
                        child: Text('player'),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter then leave a route that carries the player route name.
    await tester.tap(find.byKey(const ValueKey('push-player')).first);
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);

    rootNavigatorKey.currentState!.pop();
    await tester.pump(); // didPop → observer schedules the 2s prompt timer

    // Not yet 2s after the exit: no dialog.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byWidgetPredicate((widget) => widget is AppDialog), findsNothing);

    // Past the 2s delay: the support dialog is presented and the prompt is
    // recorded so it never auto-shows again.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is AppDialog), findsOneWidget);
    expect(prefs.getBool('donation_support_prompted'), isTrue);
  });

  testWidgets('a confirmed donation mutes the prompt permanently',
      (tester) async {
    // Watch time is far past the threshold and no prompt was recorded yet:
    // only the donation flag can keep the dialog away.
    SharedPreferences.setMockInitialValues({
      'watch_time_seconds': 99999,
      'donation_support_donated': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserGuidProvider.overrideWithValue(null),
        ],
        child: Consumer(
          builder: (context, ref, _) => FluentApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorKey: rootNavigatorKey,
            navigatorObservers: [
              SupportAuthorPromptObserver(ref.read(_refProbeProvider)),
            ],
            home: Builder(
              builder: (context) => Button(
                key: const ValueKey('push-player'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    PageRouteBuilder<void>(
                      settings: const RouteSettings(name: '/player/:guid'),
                      pageBuilder: (_, __, ___) => const SizedBox.expand(
                        child: Text('player'),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('push-player')).first);
    await tester.pumpAndSettle();
    rootNavigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((widget) => widget is AppDialog), findsNothing);
    expect(prefs.getBool('donation_support_prompted'), isNull);
  });

  testWidgets('below-threshold watch time never prompts', (tester) async {
    SharedPreferences.setMockInitialValues({'watch_time_seconds': 3600});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserGuidProvider.overrideWithValue(null),
        ],
        child: Consumer(
          builder: (context, ref, _) => FluentApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorKey: rootNavigatorKey,
            navigatorObservers: [
              SupportAuthorPromptObserver(ref.read(_refProbeProvider)),
            ],
            home: Builder(
              builder: (context) => Button(
                key: const ValueKey('push-player'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    PageRouteBuilder<void>(
                      settings: const RouteSettings(name: '/player/:guid'),
                      pageBuilder: (_, __, ___) => const SizedBox.expand(
                        child: Text('player'),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('push-player')).first);
    await tester.pumpAndSettle();
    rootNavigatorKey.currentState!.pop();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((widget) => widget is AppDialog), findsNothing);
    expect(prefs.getBool('donation_support_prompted'), isNull);
  });
}
