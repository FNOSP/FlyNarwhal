import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/data/models/movie_detail_models.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/features/movie_detail/detail_components.dart';

ItemResponse _movie() => ItemResponse(
      guid: 'm1',
      trimId: null,
      tvTitle: '',
      parentTitle: '',
      title: 'Pearl Harbor',
      posters: '',
      posterWidth: 0,
      posterHeight: 0,
      voteAverage: '0',
      isFavorite: 0,
      isWatched: 0,
      watchedTs: 0,
      seasonNumber: 0,
      numberOfSeasons: 0,
      numberOfEpisodes: 0,
      localNumberOfEpisodes: 0,
      localNumberOfSeasons: 0,
      canPlay: 1,
      type: 'Movie',
      playError: '',
      parentGuid: '',
      ancestorName: '',
      playItemGuid: 'm1',
      duration: 0,
      logicType: 0,
      episodeNumber: 0,
    );

Widget _host({String? status, VoidCallback? onTap}) => FluentApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FluentLocalizations.localizationsDelegates,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: ScaffoldPage(
        content: Align(
          alignment: Alignment.topRight,
          child: DetailTags(
            item: _movie(),
            thumbnailStatusText: status,
            onThumbnailStatusTap: onTap,
          ),
        ),
      ),
    );

void main() {
  testWidgets('a failed status with a tap handler renders as a clickable link',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var tapped = 0;
    await tester.pumpWidget(_host(status: '生成失败', onTap: () => tapped++));
    await tester.pumpAndSettle();

    final label = find.textContaining('缩略图预览');
    expect(label, findsOneWidget);

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tapped, 1, reason: 'the status line must open the failure detail');
  });

  testWidgets('without a handler the status stays plain text', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(status: '已生成'));
    await tester.pumpAndSettle();

    expect(find.textContaining('缩略图预览'), findsOneWidget);
    final rich = tester.widget<Text>(find.textContaining('缩略图预览'));
    expect(rich.textSpan, isNull, reason: 'no link without a reason to open');
  });

  testWidgets('no status at all renders no sprite tag', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.textContaining('缩略图预览'), findsNothing);
  });
}