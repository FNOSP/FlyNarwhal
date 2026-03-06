---
name: flutter-tester
description: Use when creating, writing, fixing, or reviewing tests in a Flutter project. Covers unit tests, widget tests, integration tests, Riverpod provider testing, and Mockito mocking. Provides Given-When-Then patterns, layer isolation strategies, and test setup for GetIt, SharedPreferences, and FakeDatabase.
compatibility: Requires a Flutter project with flutter_test. Works with Riverpod, Mockito, and GetIt. Run `dart run build_runner build` to generate mocks after adding @GenerateMocks annotations. Compatible with FVM.
metadata:
  author: harish
  version: 1.0.0
---

# Flutter Tester

## Overview

Test each architectural layer in isolation using Given-When-Then structure. Always test both success and error paths. Never mock providers — override their dependencies instead.

## Reference Files

Load the relevant file based on what you're testing:

| What you're testing | Reference file |
| --- | --- |
| Repository, DAO, Service logic | `references/layer_testing_patterns.md` |
| Widget UI, interactions, dialogs, navigation | `references/widget_testing_guide.md` |
| Riverpod provider state, mutations, lifecycle | `references/riverpod_testing_guide.md` |

## Core Principles

### 1. Layer Isolation

Test each layer against its own mocked dependencies:

| Layer | What to test | What to mock |
| --- | --- | --- |
| **Repository** | Data coordination between sources | DAOs, APIs, Logger |
| **DAO** | Database CRUD operations | Use real in-memory DB, mock Logger |
| **Provider** | State management and transitions | Services, Repositories |
| **Service** | Business logic and workflows | Repositories, Network clients |
| **Widget** | UI behaviour and interactions | Provider dependencies (via overrides) |

### 2. Given-When-Then Structure

```dart
test('Given valid data, When fetchUsers called, Then returns user list', () async {
  // Arrange (Given)
  when(mockDAO.fetchAll()).thenAnswer((_) async => expectedUsers);

  // Act (When)
  final result = await repository.fetchUsers();

  // Assert (Then)
  expect(result, equals(expectedUsers));
  verify(mockDAO.fetchAll()).called(1);
});
```

### 3. Test Organisation

```dart
group('UserRepository', () {
  group('fetchUsers', () {
    setUp(() { /* init mocks, register with GetIt */ });
    tearDown(() => GetIt.I.reset()); // Always reset GetIt

    test('Given success ... When ... Then ...', () { });
    test('Given error  ... When ... Then ...', () { });
  });
});
```

## Standard Test Setup

### Generate Mocks

```dart
@GenerateMocks([IUserDAO, IUserAPI, ILogger])
void main() { ... }
```

Run `dart run build_runner build` after modifying `@GenerateMocks`.

### Register with GetIt

```dart
setUp(() {
  mockDAO = MockIUserDAO();
  mockLogger = MockILogger();
  GetIt.I
    ..registerSingleton<IUserDAO>(mockDAO)
    ..registerSingleton<ILogger>(mockLogger);
});

tearDown(() => GetIt.I.reset()); // Critical — always reset
```

### Fakes vs Mocks

- **Fakes** (`class FakeLogger extends ILogger`) — silent stubs; use when you don't need to verify calls
- **Mocks** (`MockILogger`) — use when you need `when()`, `verify()`, or `thenThrow()`

## Quick Reference

| Scenario | Key pattern |
| --- | --- |
| Test a repository | Mock DAO + API → inject into repository constructor |
| Test a DAO | `FakeDatabase` or `openInMemoryDatabase()` in setUp, delete table in tearDown |
| Test a Riverpod provider | `createContainer(overrides: [serviceProvider.overrideWith(...)])` |
| Test a widget | Set screen size, use `find.byKey()`, call `pumpAndSettle()` |
| Test a loading state | Use `Completer`, `pump()` to assert loading, complete, `pump()` again |
| Test platform-specific UI | `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` — reset after |
| Test GoRouter navigation | `FakeGoRouter` + `MockGoRouterProvider` |

## Running Tests

```bash
flutter test --coverage                       # All tests with coverage
flutter test test/path/to/test.dart           # Specific file
flutter test --plain-name "Given valid data"  # Filter by name
genhtml coverage/lcov.info -o coverage/html   # Generate HTML coverage report
# Prefix any command with `fvm` if using Flutter Version Manager
```

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Mocking a provider directly | Override its dependencies: `provider.overrideWith(...)` |
| Missing `GetIt.I.reset()` in `tearDown` | Tests pollute each other — always reset |
| `await Future.delayed()` in tests | Use `await tester.pumpAndSettle()` or `Completer` instead |
| Finding widgets by text string | Use `find.byKey(const Key('name'))` — stable across text changes |
| No screen size in widget tests | Add `tester.view.physicalSize = const Size(1000, 1000)` |
| Not resetting `debugDefaultTargetPlatformOverride` | Set to `null` at the end of the test |
| `tearDown()` without a lambda | Write `tearDown(() async { ... })` not `tearDown() async { ... }` |

## Test Checklist

**Setup & Mocking:**

- [ ] Dependencies mocked (not providers)
- [ ] SharedPreferences mocked if used
- [ ] `GetIt.I.reset()` in `tearDown`
- [ ] Streams closed in `tearDown`
- [ ] Controllers disposed in `tearDown`

**Widget Tests:**

- [ ] Keys added to source widgets and used in `find.byKey()`
- [ ] Screen size set (`physicalSize` + `devicePixelRatio`)
- [ ] Platform overrides reset (`debugDefaultTargetPlatformOverride = null`)
- [ ] Navigation verified if applicable

**Test Coverage:**

- [ ] Success and failure paths covered
- [ ] Edge cases tested (null, empty, max values)
- [ ] Loading and error states tested
- [ ] Async handled correctly (no `Future.delayed`)

**Code Quality:**

- [ ] Given-When-Then naming used
- [ ] `verify()` or `verifyNever()` where appropriate
- [ ] Tests are isolated and deterministic
