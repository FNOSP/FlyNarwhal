import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/ui/shared/filter_box.dart';

const Color _selectedColor = Color(0xFF2073DF);

Future<void> _pumpFilterBox(
  WidgetTester tester, {
  Map<String, FilterItem> initialSelectedFilters = const {},
}) async {
  await tester.pumpWidget(
    FluentApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: ScaffoldPage(
          content: SingleChildScrollView(
          child: FilterBox(
            categoryType: 'video',
            initialSelectedFilters: initialSelectedFilters,
            onFilterChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Text> _allLabels(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.text('全部'))
      .where((t) => t.style?.fontWeight == FontWeight.w600)
      .toList();
}

void main() {
  testWidgets('every filter row defaults to the All option', (tester) async {
    await _pumpFilterBox(tester);
    final labels = _allLabels(tester);
    expect(labels, isNotEmpty);
    for (final text in labels) {
      expect(text.style?.color, _selectedColor,
          reason: 'row "${text.data}" should start on the All option');
    }
  });

  testWidgets('cleared placeholder still resolves to the All option',
      (tester) async {
    await _pumpFilterBox(tester, initialSelectedFilters: {
      FilterRowKey.genre: const FilterItem('', null),
      FilterRowKey.resolution: const FilterItem('', null),
    });
    final labels = _allLabels(tester);
    expect(labels, isNotEmpty);
    for (final text in labels) {
      expect(text.style?.color, _selectedColor);
    }
  });
}
