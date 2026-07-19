---
name: flutter-tester
description: A comprehensive Flutter testing skill for creating, writing, and analyzing tests in any Flutter project. Provides guidance on test structure, mocking patterns, Riverpod testing, widget testing, and industry best practices for reliable, maintainable tests.
---

# Flutter Tester

## Overview

This skill provides comprehensive guidance for writing consistent, reliable, and maintainable tests for Flutter applications. Follow the testing patterns, mocking strategies, and architectural guidelines to ensure tests are isolated, repeatable, and cover both success and error scenarios. This skill works with any Flutter project using common packages like Riverpod, Mockito, and flutter_test.

## When to Use This Skill

Use this skill when:

- Creating new unit tests for repositories, providers, DAOs, or services
- Writing widget tests for UI components and views
- Setting up mocks and test dependencies with Mockito and Riverpod
- Implementing Given-When-Then test structure
- Testing state management with Riverpod providers
- Writing integration tests for multi-layer workflows
- Debugging or fixing existing tests
- Ensuring proper test coverage across data, domain, and presentation layers

## Core Testing Principles

### 1. Clean Architecture Testing

Test each layer in **isolation**:

- **Data Layer** → DAOs, APIs, Repositories
- **Domain Layer** → Models (Freezed), Entities
- **Presentation Layer** → Providers (Riverpod), Views, Controllers

### 2. Given-When-Then Structure

Always structure tests using Given-When-Then pattern:

```dart
test('Given valid data, When operation executes, Then returns expected result', () async {
  // Arrange (Given)
  when(mockDAO.getData()).thenAnswer((_) async => testData);

  // Act (When)
  final result = await repository.fetchData();

  // Assert (Then)
  expect(result, equals(testData));
  verify(mockDAO.getData()).called(1);
});
```

### 3. Test Organization

- Group related tests using `group()` blocks
- Use `setUp()` for common initialization
- Use `tearDown()` for cleanup (reset GetIt, dispose resources)
- Use `setUpAll()` for one-time expensive setup

## Testing Workflow

### Step 1: Identify the Layer Under Test

Determine which architectural layer you're testing:

- **Repository tests** → Mock DAOs and APIs
- **Provider tests** → Mock services and repositories
- **Widget tests** → Mock providers and services
- **DAO tests** → Use FakeDatabase

### Step 2: Set Up Dependencies and Mocks

#### Generate Mocks with Mockito

```dart
@GenerateMocks([ILogger, ICarouselRepository, INotificationDAO])
void main() {
  // Test code
}
```

**Important**: Never mock providers directly. Override their dependencies instead.

#### Register with GetIt

```dart
setUp(() {
  mockLogger = MockILogger();
  mockRepository = MockICarouselRepository();
  GetIt.I.registerSingleton<ILogger>(mockLogger);
  GetIt.I.registerSingleton<ICarouselRepository>(mockRepository);
});

tearDown(() => GetIt.I.reset());
```

#### SharedPreferences Setup

```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({'key1': 'value1'});
  SharedPrefManager.instance = await SharedPreferences.getInstance();
});
```

### Step 3: Write Tests Following Layer Patterns

Refer to the `references/layer_testing_patterns.md` file for detailed examples of:

- Repository testing patterns
- Provider testing patterns with Riverpod
- DAO testing patterns with FakeDatabase
- Widget testing patterns with keys and screen size setup

### Step 4: Test Error Scenarios

Always test both success and failure paths:

```dart
test('Given service throws exception, When called, Then logs error and returns fallback', () async {
  // Arrange
  final exception = Exception('Network error');
  when(mockService.fetchData()).thenThrow(exception);

  // Act
  final result = await repository.getData();

  // Assert
  expect(result, isEmpty); // Or appropriate fallback
  verify(mockLogger.writeExceptionLog('RepositoryName', 'getData', exception, any)).called(1);
});
```

## Widget Testing Essentials

### Always Set Screen Size

```dart
testWidgets('Test description', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  // Your test code
});
```

### Always Use Keys for Widget Finding

**In source code:**

```dart
ElevatedButton(
  key: const Key('saveButton'),
  onPressed: () {},
  child: const Text('Save'),
);
```

**In test:**

```dart
await tester.tap(find.byKey(const Key('saveButton')));
await tester.pumpAndSettle();
```

If a key doesn't exist in the source widget, **add it** before writing the test.

### Loading → Content Transitions

```dart
when(mockService.fetchData()).thenAnswer((_) async => data);

await tester.pumpWidget(createTestWidget());
expect(find.byType(CircularProgressIndicator), findsOneWidget);

await tester.pumpAndSettle();
expect(find.byType(DataWidget), findsOneWidget);
```

### Platform-Specific Testing

```dart
testWidgets('iOS specific behavior', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  await tester.pumpWidget(createTestWidget());

  expect(find.byType(CupertinoButton), findsOneWidget);

  debugDefaultTargetPlatformOverride = null;
});
```

## Riverpod Testing

### Create Container with Overrides

```dart
final container = createContainer(overrides: [
  repoProvider.overrideWith((ref) => mockRepo),
]);
```

Use the `createContainer()` helper from `test/riverpod_container.dart` which auto-disposes on tearDown.

### Test Provider State

```dart
test('Given valid data, When state updates, Then reflects new value', () async {
  final notifier = container.read(provider.notifier);

  notifier.updateState(newValue);

  expect(container.read(provider).value!.property, newValue);
});
```

### Test Initial State

```dart
test('Given empty data, When building initial state, Then returns default state', () async {
  when(mockService.fetchData()).thenAnswer((_) async => []);

  final container = createContainer();
  final state = await container.read(provider.notifier).future;

  expect(state.data, isEmpty);
  expect(state.isLoading, false);
});
```

## Stubbing Patterns

### Success Scenarios

```dart
when(mockRepo.fetchFromDb()).thenAnswer((_) async => mockData);
when(mockApi.updateData(any, any, any)).thenAnswer((_) async => true);
```

### Failure Scenarios

```dart
when(mockRepo.fetchFromDb()).thenThrow(Exception('DB error'));
when(mockApi.updateData(any, any, any)).thenAnswer((_) async => false);
```

### Using Completers for Async Control

```dart
final completer = Completer<RegistrationModel>();

when(mockRepo.fetchData(any, any)).thenAnswer((_) => completer.future);

await tester.tap(find.text('Save'));
await tester.pump();

expect(find.byType(CircularProgressIndicator), findsOneWidget);

completer.complete(const RegistrationModel(status: 'success'));
await tester.pump();

expect(find.byType(CircularProgressIndicator), findsNothing);
```

## Fakes vs Mocks

### When to Use Fakes

Use fake implementations for consistent dummy behavior:

```dart
class FakeLogger extends ILogger {
  @override
  void writeInfoLog(String className, String method, String message) {}

  @override
  void writeErrorLog(String className, String method, dynamic error, StackTrace? stack, [String? msg]) {}
}
```

Register in test setup:

```dart
GetIt.I.registerSingleton<ILogger>(FakeLogger.i);
```

### When to Use Mocks

Use mocks when you need to verify method calls or setup specific behaviors:

```dart
when(mockLogger.writeErrorLog(any, any, any, any)).thenReturn(null);
verify(mockLogger.writeErrorLog('ClassName', 'methodName', exception, any)).called(1);
```

## Database Testing with FakeDatabase

```dart
late MenuDAO menuDAO;
late Database db;
late IDatabase mockDatabase;

setUp(() async {
  await FakePathProviderPlatform.initialize();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  mockDatabase = FakeDatabase();
  db = await mockDatabase.database;

  menuDAO = MenuDAO(
    dbManager: mockDatabase,
    logger: mockLogger,
  );
});

tearDown() async {
  await menuDAO.deleteTable();
  if (GetIt.I.isRegistered<IDatabase>()) {
    await GetIt.I<IDatabase>().close();
  }
  await GetIt.I.reset();
  await FakePathProviderPlatform.cleanup();
}
```

## Test Checklist

Before submitting tests, ensure:

**Setup & Mocking:**

- [ ] Dependencies mocked (not providers)
- [ ] SharedPreferences mocked if used
- [ ] GetIt reset in tearDown
- [ ] Streams closed in tearDown
- [ ] Controllers disposed in tearDown

**Widget Tests:**

- [ ] **Keys added & used in widget tests**
- [ ] Screen size set (physicalSize + devicePixelRatio)
- [ ] Platform overrides reset (debugDefaultTargetPlatformOverride = null)
- [ ] Navigation tested if applicable
- [ ] Dialogs/overlays tested if shown

**Test Coverage:**

- [ ] Success & failure paths covered
- [ ] Edge cases tested (null, empty, max values)
- [ ] Loading states tested
- [ ] Error states tested
- [ ] Async handled correctly (await, Completer)

**Code Quality:**

- [ ] Given-When-Then naming used
- [ ] verify() or verifyNever() used where appropriate
- [ ] No hardcoded delays (use pump/pumpAndSettle)
- [ ] Tests are isolated (no dependencies between tests)
- [ ] Tests are deterministic (same result every time)

## Common Patterns

### Verification Patterns

```dart
// Single call
verify(mockService.method()).called(1);

// Multiple calls
verify(mockService.method()).called(3);

// Never called
verifyNever(mockService.method());

// Ordered calls
verifyInOrder([
  mockService.method1(),
  mockService.method2(),
]);
```

### Testing Global State

```dart
import 'package:your_app/path/to/global_variables.dart' as global_variables;

setUp(() {
  global_variables.someGlobalVariable = initialValue;
});

tearDown(() {
  global_variables.someGlobalVariable = initialValue; // Reset to default
});
```

### Testing Dispose/Cleanup

```dart
testWidgets('Given provider disposed, When container disposed, Then unsubscribes and cleans up', () async {
  final container = createContainer();
  final notifier = container.read(provider.notifier);
  await notifier.future;

  container.dispose();

  verify(mockService.unsubscribe(any, any)).called(1);
  verify(mockService.dispose(any)).called(1);
});
```

## Running Tests

### Run All Tests

```bash
flutter test --coverage
# Or if using FVM:
fvm flutter test --coverage
```

### Run Specific Test File

```bash
flutter test test/path/to/your_test.dart
# Or if using FVM:
fvm flutter test test/path/to/your_test.dart
```

### Run Specific Test by Name

```bash
flutter test --plain-name "Given valid data"
# Or if using FVM:
fvm flutter test --plain-name "Given valid data"
```

### Generate Coverage Report

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Or if using FVM:
fvm flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Test Helpers and Utilities

### Creating a Test Widget Wrapper

```dart
Widget createTestWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

// With Riverpod
Widget createTestWidgetWithProviders(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}
```

### Reusable Riverpod Container Helper

```dart
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
```

### Finding Widgets by Type and Text

```dart
// Find by type
expect(find.byType(CircularProgressIndicator), findsOneWidget);

// Find by text
expect(find.text('Hello'), findsOneWidget);

// Find by key
expect(find.byKey(const Key('myKey')), findsOneWidget);

// Find descendant
expect(
  find.descendant(
    of: find.byType(Container),
    matching: find.text('Child'),
  ),
  findsOneWidget,
);

// Find ancestor
expect(
  find.ancestor(
    of: find.text('Child'),
    matching: find.byType(Container),
  ),
  findsOneWidget,
);
```

### Matchers for Better Assertions

```dart
// Common matchers
expect(value, equals(expected));
expect(value, isNotNull);
expect(value, isNull);
expect(list, isEmpty);
expect(list, isNotEmpty);
expect(list, hasLength(3));
expect(list, contains('item'));
expect(list, containsAll(['a', 'b']));
expect(value, greaterThan(5));
expect(value, lessThan(10));
expect(value, inRange(1, 10));

// Custom matchers
expect(find.byType(Widget), findsOneWidget);
expect(find.byType(Widget), findsNothing);
expect(find.byType(Widget), findsWidgets);
expect(find.byType(Widget), findsNWidgets(3));
```

## Additional Testing Patterns

### Testing with GetIt Dependency Injection

```dart
setUp(() {
  GetIt.I.registerSingleton<ApiService>(mockApiService);
  GetIt.I.registerLazySingleton<UserRepository>(() => UserRepository());
});

tearDown(() {
  GetIt.I.reset(); // Always reset GetIt between tests
});
```

### Testing Stream-Based Code

```dart
test('Given stream emits values, When listening, Then receives all values', () async {
  // Arrange
  final streamController = StreamController<int>();
  final values = <int>[];

  // Act
  streamController.stream.listen(values.add);
  streamController.add(1);
  streamController.add(2);
  streamController.add(3);
  await streamController.close();

  // Wait for stream to complete
  await Future.delayed(Duration.zero);

  // Assert
  expect(values, equals([1, 2, 3]));
});
```

### Testing Timer-Based Code

```dart
testWidgets('Given timer completes, When countdown finishes, Then shows message', (tester) async {
  await tester.pumpWidget(MyTimerWidget());

  // Fast-forward time
  await tester.pump(const Duration(seconds: 5));

  expect(find.text('Time is up!'), findsOneWidget);
});
```

### Testing Scrollable Widgets

```dart
testWidgets('Given long list, When scrolling, Then finds bottom item', (tester) async {
  await tester.pumpWidget(MyLongListWidget());

  // Scroll until item is visible
  await tester.scrollUntilVisible(
    find.text('Item 99'),
    500.0,
  );

  expect(find.text('Item 99'), findsOneWidget);
});
```

## Resources

This skill includes reference files with detailed patterns and examples:

### references/

- `layer_testing_patterns.md` - Comprehensive examples for testing repositories, providers, DAOs, and services
- `widget_testing_guide.md` - Detailed widget testing patterns with keys, screen size, and user interactions
- `riverpod_testing_guide.md` - Advanced Riverpod provider testing patterns and state management testing

Refer to these references when you need specific implementation examples or encounter complex testing scenarios.