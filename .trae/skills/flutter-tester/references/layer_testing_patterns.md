# Layer Testing Patterns

This file provides comprehensive examples for testing each architectural layer in Flutter applications.

## Repository Layer Testing

Repositories coordinate between DAOs and APIs. Test both success and error scenarios.

### Basic Repository Test Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([UserDAO, UserAPI, Logger])
void main() {
  late UserRepository repository;
  late MockUserDAO mockDAO;
  late MockUserAPI mockAPI;
  late MockLogger mockLogger;

  setUp(() {
    mockDAO = MockUserDAO();
    mockAPI = MockUserAPI();
    mockLogger = MockLogger();

    repository = UserRepository(
      dao: mockDAO,
      api: mockAPI,
      logger: mockLogger,
    );
  });

  group('UserRepository', () {
    group('fetchUsers', () {
      test('Given successful DAO call, when fetchUsers is called, then returns list', () async {
        // Arrange
        final expectedUsers = [
          User(id: '1', name: 'John'),
          User(id: '2', name: 'Jane'),
        ];
        when(mockDAO.fetchAll()).thenAnswer((_) async => expectedUsers);

        // Act
        final result = await repository.fetchUsers();

        // Assert
        expect(result, equals(expectedUsers));
        verify(mockDAO.fetchAll()).called(1);
      });

      test('Given DAO throws exception, when fetchUsers is called, then returns empty and logs error', () async {
        // Arrange
        final exception = Exception('Database error');
        when(mockDAO.fetchAll()).thenThrow(exception);

        // Act
        final result = await repository.fetchUsers();

        // Assert
        expect(result, isEmpty);
        verify(mockDAO.fetchAll()).called(1);
        verify(mockLogger.logException('UserRepository', 'fetchUsers', exception, any)).called(1);
      });
    });

    group('syncWithAPI', () {
      test('Given successful API sync, when syncWithAPI is called, then updates database', () async {
        // Arrange
        final apiData = [User(id: '1', name: 'John Updated')];
        when(mockAPI.fetchUsers()).thenAnswer((_) async => apiData);
        when(mockDAO.insertAll(any)).thenAnswer((_) async => 1);

        // Act
        await repository.syncWithAPI();

        // Assert
        verify(mockAPI.fetchUsers()).called(1);
        verify(mockDAO.insertAll(apiData)).called(1);
      });

      test('Given API throws exception, when syncWithAPI is called, then logs error and does not update DB', () async {
        // Arrange
        final exception = Exception('Network error');
        when(mockAPI.fetchUsers()).thenThrow(exception);

        // Act
        await repository.syncWithAPI();

        // Assert
        verify(mockAPI.fetchUsers()).called(1);
        verifyNever(mockDAO.insertAll(any));
        verify(mockLogger.logException('UserRepository', 'syncWithAPI', exception, any)).called(1);
      });
    });
  });
}
```

### Repository Testing Key Patterns

- **Mock both data sources** (DAO and API)
- **Test success paths** - Verify data flows correctly
- **Test error paths** - Verify exceptions are handled and logged
- **Verify method calls** - Use `verify()` to ensure dependencies are called correctly
- **Use `verifyNever()`** - Ensure methods aren't called when they shouldn't be

## DAO Layer Testing

DAOs interact with the database. Use FakeDatabase for realistic testing.

### Basic DAO Test Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

@GenerateMocks([Logger])
void main() {
  late ItemDAO itemDAO;
  late Database db;
  late MockLogger mockLogger;

  setUp(() async {
    // Setup fake database (implementation depends on your project)
    db = await openInMemoryDatabase();
    mockLogger = MockLogger();

    itemDAO = ItemDAO(
      database: db,
      logger: mockLogger,
    );

    // Create tables
    await itemDAO.createTable();
  });

  tearDown(() async {
    await itemDAO.deleteTable();
    await db.close();
  });

  group('ItemDAO', () {
    group('insert', () {
      test('Given valid item, when insert is called, then item is added to database', () async {
        // Arrange
        final item = Item(id: '1', name: 'Test Item');

        // Act
        final result = await itemDAO.insert(item);

        // Assert
        expect(result, greaterThan(0)); // Row ID returned
        final fetchedItems = await itemDAO.fetchAll();
        expect(fetchedItems, hasLength(1));
        expect(fetchedItems.first.name, 'Test Item');
      });

      test('Given insert fails, when insert is called, then logs exception', () async {
        // Arrange
        final invalidItem = Item(id: null, name: null); // Invalid data

        // Act & Assert
        expect(() => itemDAO.insert(invalidItem), throwsException);
      });
    });

    group('fetchAll', () {
      test('Given items in database, when fetchAll is called, then returns all items', () async {
        // Arrange
        await itemDAO.insert(Item(id: '1', name: 'Item 1'));
        await itemDAO.insert(Item(id: '2', name: 'Item 2'));

        // Act
        final result = await itemDAO.fetchAll();

        // Assert
        expect(result, hasLength(2));
        expect(result.map((i) => i.name), containsAll(['Item 1', 'Item 2']));
      });

      test('Given empty database, when fetchAll is called, then returns empty list', () async {
        // Act
        final result = await itemDAO.fetchAll();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('update', () {
      test('Given existing item, when update is called, then item is updated', () async {
        // Arrange
        await itemDAO.insert(Item(id: '1', name: 'Original'));
        final updatedItem = Item(id: '1', name: 'Updated');

        // Act
        await itemDAO.update(updatedItem);

        // Assert
        final result = await itemDAO.fetchAll();
        expect(result.first.name, 'Updated');
      });
    });

    group('delete', () {
      test('Given existing item, when delete is called, then item is removed', () async {
        // Arrange
        await itemDAO.insert(Item(id: '1', name: 'To Delete'));

        // Act
        await itemDAO.delete('1');

        // Assert
        final result = await itemDAO.fetchAll();
        expect(result, isEmpty);
      });
    });
  });
}
```

### DAO Testing Key Patterns

- **Use in-memory database** - Fast and isolated tests
- **Create/delete tables** in setUp/tearDown
- **Test CRUD operations** - Create, Read, Update, Delete
- **Test empty states** - Verify behavior with no data
- **Test data integrity** - Ensure inserts/updates work correctly

## Provider Layer Testing (Riverpod)

Providers manage state. Test state transitions and async flows.

### Basic Provider Test Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@GenerateMocks([DataService, Logger])
void main() {
  late MockDataService mockService;
  late MockLogger mockLogger;

  setUp(() {
    mockService = MockDataService();
    mockLogger = MockLogger();
  });

  group('DataProvider', () {
    test('Given service returns data, when provider builds, then state contains data', () async {
      // Arrange
      final expectedData = [
        DataModel(id: '1', name: 'Item 1'),
        DataModel(id: '2', name: 'Item 2'),
      ];
      when(mockService.fetchData()).thenAnswer((_) async => expectedData);

      // Create container with overrides
      final container = ProviderContainer(
        overrides: [
          dataServiceProvider.overrideWithValue(mockService),
          loggerProvider.overrideWithValue(mockLogger),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final state = await container.read(dataProvider.future);

      // Assert
      expect(state, equals(expectedData));
      verify(mockService.fetchData()).called(1);
    });

    test('Given service throws exception, when provider builds, then error state is set', () async {
      // Arrange
      final exception = Exception('Network error');
      when(mockService.fetchData()).thenThrow(exception);

      final container = ProviderContainer(
        overrides: [
          dataServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      // Act & Assert
      expect(
        () => container.read(dataProvider.future),
        throwsA(exception),
      );
    });

    test('Given state changes, when updateData is called, then new state is emitted', () async {
      // Arrange
      when(mockService.fetchData()).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          dataServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dataProvider.notifier);
      final newData = [DataModel(id: '3', name: 'New Item')];

      // Act
      notifier.updateData(newData);

      // Assert
      final state = container.read(dataProvider);
      expect(state.value, equals(newData));
    });
  });
}
```

### Provider Testing Key Patterns

- **Override providers** - Use `ProviderContainer` with overrides
- **Test async states** - Handle loading, data, and error states
- **Dispose containers** - Use `addTearDown(container.dispose)`
- **Test state changes** - Verify notifier methods update state correctly
- **Mock service dependencies** - Never mock providers directly

## Service Layer Testing

Services contain business logic. Test the logic, not the implementation.

### Basic Service Test Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([Repository, Logger, NetworkClient])
void main() {
  late DataService service;
  late MockRepository mockRepository;
  late MockLogger mockLogger;
  late MockNetworkClient mockClient;

  setUp(() {
    mockRepository = MockRepository();
    mockLogger = MockLogger();
    mockClient = MockNetworkClient();

    service = DataService(
      repository: mockRepository,
      logger: mockLogger,
      client: mockClient,
    );
  });

  group('DataService', () {
    test('Given cached data exists, when getData is called, then returns cached data without API call', () async {
      // Arrange
      final cachedData = [DataModel(id: '1', name: 'Cached')];
      when(mockRepository.getCached()).thenAnswer((_) async => cachedData);

      // Act
      final result = await service.getData(useCache: true);

      // Assert
      expect(result, equals(cachedData));
      verify(mockRepository.getCached()).called(1);
      verifyNever(mockClient.fetch(any));
    });

    test('Given no cached data, when getData is called, then fetches from API and caches', () async {
      // Arrange
      final apiData = [DataModel(id: '2', name: 'From API')];
      when(mockRepository.getCached()).thenAnswer((_) async => null);
      when(mockClient.fetch(any)).thenAnswer((_) async => apiData);
      when(mockRepository.save(any)).thenAnswer((_) async => {});

      // Act
      final result = await service.getData(useCache: true);

      // Assert
      expect(result, equals(apiData));
      verify(mockRepository.getCached()).called(1);
      verify(mockClient.fetch(any)).called(1);
      verify(mockRepository.save(apiData)).called(1);
    });

    test('Given API call fails, when getData is called, then returns cached data as fallback', () async {
      // Arrange
      final cachedData = [DataModel(id: '1', name: 'Cached')];
      when(mockRepository.getCached()).thenAnswer((_) async => cachedData);
      when(mockClient.fetch(any)).thenThrow(Exception('Network error'));

      // Act
      final result = await service.getData(useCache: false, fallbackToCache: true);

      // Assert
      expect(result, equals(cachedData));
      verify(mockClient.fetch(any)).called(1);
      verify(mockRepository.getCached()).called(1);
    });
  });
}
```

### Service Testing Key Patterns

- **Test business logic** - Focus on the "what", not the "how"
- **Test caching strategies** - Verify cache hits/misses
- **Test fallback behavior** - Ensure graceful degradation
- **Mock all dependencies** - Services should have no direct I/O

## Summary

### Testing Each Layer

| Layer | What to Test | What to Mock |
|-------|--------------|--------------|
| **Repository** | Data coordination between sources | DAOs, APIs, Logger |
| **DAO** | Database CRUD operations | Use real in-memory DB, mock Logger |
| **Provider** | State management and transitions | Services, Repositories |
| **Service** | Business logic and workflows | Repositories, Network clients |

### Common Verification Patterns

```dart
// Verify method was called once
verify(mock.method()).called(1);

// Verify method was called with specific arguments
verify(mock.method(argThat(equals('expected')))).called(1);

// Verify method was never called
verifyNever(mock.method());

// Verify call order
verifyInOrder([
  mock.method1(),
  mock.method2(),
]);

// Verify no more interactions
verifyNoMoreInteractions(mock);
```

### Error Handling Patterns

```dart
// Test that method throws
expect(() => service.method(), throwsException);

// Test specific exception
expect(() => service.method(), throwsA(isA<CustomException>()));

// Test async throws
expect(() async => await service.method(), throwsA(isA<NetworkException>()));

// Verify logging on error
verify(mockLogger.logException(any, any, exception, any)).called(1);
```
