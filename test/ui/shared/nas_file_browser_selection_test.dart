import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fly_narwhal/data/datasources/remote/file_remote_data_source.dart';
import 'package:fly_narwhal/data/datasources/remote/subtitle_remote_data_source.dart';
import 'package:fly_narwhal/data/models/file_models.dart';
import 'package:fly_narwhal/data/repositories/file_repository.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations.dart';
import 'package:fly_narwhal/providers/file_providers.dart';
import 'package:fly_narwhal/ui/shared/nas/nas_file_browser.dart';

class _MockFileDataSource extends Mock implements FileRemoteDataSource {}

class _MockSubtitleDataSource extends Mock implements SubtitleRemoteDataSource {}

class _FakeFileRepository extends FileRepository {
  _FakeFileRepository(this.tree)
      : super(
          fileDataSource: _MockFileDataSource(),
          subtitleDataSource: _MockSubtitleDataSource(),
        );

  final Map<String, List<ServerPathResponse>> tree;

  @override
  Future<List<ServerPathResponse>> getFilesByServerPath(String path) async {
    return tree[path] ?? const [];
  }
}

ServerPathResponse dir(String name) =>
    ServerPathResponse(filename: name, isDir: true);
ServerPathResponse file(String name) =>
    ServerPathResponse(filename: name, isDir: false);

Future<void> _pumpBrowser(
  WidgetTester tester, {
  required NasBrowserSelectionMode mode,
  required ValueChanged<Set<String>> onSelectionChanged,
  Set<String> initialSelection = const {},
}) async {
  final repository = _FakeFileRepository({
    '/vol1': [dir('movies'), file('notes.txt')],
    '/vol1/movies': [file('a.mp4')],
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
      child: FluentApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: ScaffoldPage(
          content: SizedBox(
            width: 400,
            height: 400,
            child: NasFileBrowser(
              roots: const [NasBrowserRoot(path: '/vol1')],
              sidebarTitle: 'vol1',
              selectionMode: mode,
              initialSelection: initialSelection,
              onSelectionChanged: onSelectionChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('directories mode: directory rows are checkable, files are not',
      (tester) async {
    Set<String>? lastSelection;
    await _pumpBrowser(
      tester,
      mode: NasBrowserSelectionMode.directories,
      onSelectionChanged: (paths) => lastSelection = paths,
    );

    // Expand the root volume row.
    await tester.tap(find.text('vol1'));
    await tester.pumpAndSettle();
    expect(find.text('movies'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);

    // The directory row carries an enabled checkbox; the file row does not.
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.length, 2, reason: 'root + movies are checkable');
    expect(checkboxes.every((c) => c.onChanged != null), isTrue);

    // Checking the directory reports its path.
    await tester.tap(find.byKey(const ValueKey('nas-tree-check-1-0')));
    await tester.pumpAndSettle();
    expect(lastSelection, {'/vol1/movies'});
  });

  testWidgets('files mode keeps the historical behavior', (tester) async {
    Set<String>? lastSelection;
    await _pumpBrowser(
      tester,
      mode: NasBrowserSelectionMode.files,
      onSelectionChanged: (paths) => lastSelection = paths,
    );

    await tester.tap(find.text('vol1'));
    await tester.pumpAndSettle();

    // The file row is checkable and toggling it reports the file path.
    await tester.tap(find.byKey(const ValueKey('nas-tree-check-1-1')));
    await tester.pumpAndSettle();
    expect(lastSelection, {'/vol1/notes.txt'});
  });

  testWidgets('initialSelection is echoed back and pre-checked',
      (tester) async {
    Set<String>? lastSelection;
    await _pumpBrowser(
      tester,
      mode: NasBrowserSelectionMode.directories,
      initialSelection: const {'/vol1/movies'},
      onSelectionChanged: (paths) => lastSelection = paths,
    );
    expect(lastSelection, {'/vol1/movies'});

    await tester.tap(find.text('vol1'));
    await tester.pumpAndSettle();
    final moviesCheckbox = tester.widget<Checkbox>(
        find.byKey(const ValueKey('nas-tree-check-1-0')));
    expect(moviesCheckbox.checked, isTrue);
  });
}
