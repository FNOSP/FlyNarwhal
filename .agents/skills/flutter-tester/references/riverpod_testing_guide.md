# Riverpod Testing Guide

This file provides advanced patterns for testing Riverpod providers in the Flutter application.

## Core Principle: Never Mock Providers

**❌ DON'T** mock providers:

```dart
// BAD - Don't do this!
@GenerateMocks([NotificationNotifierProvider])
```

**✅ DO** override provider dependencies:

```dart
final container = createContainer(overrides: [
  notificationServiceProvider.overrideWith((ref) => mockNotificationService),
]);
```

## Container Setup

### Using createContainer Helper

The project includes a `createContainer()` helper that auto-disposes:

```dart
import '../../../../riverpod_container.dart';

final container = createContainer(overrides: [
  serviceProvider.overrideWith((ref) => mockService),
]);

// Container automatically disposed in addTearDown
```

### Manual Container Setup

```dart
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  addTearDown(container.dispose);

  return container;
}
```

## Testing AsyncNotifierProvider

### Testing Initial State (build method)

```dart
test('Given empty notifications and default audio config, '
    'when building initial state, '
    'then should return default NotificationState', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer();

  // Act
  final notifier = container.read(notificationNotifierProvider.notifier);
  final state = await notifier.future;

  // Assert
  expect(state.notifications, isEmpty);
  expect(state.isAudioEnabled, true);
  expect(state.isAudioMuted, false);
  expect(state.shouldPlayAudio, false);
  expect(state.audioFileNames, isEmpty);
  expect(state.userList, isEmpty);
  expect(state.audioFileIndex, 0);
  expect(state.wasRadioPlaying, false);

  verify(mockNotificationService.fetchNotifications()).called(1);
  verify(mockNotificationService.getAudioConfiguration()).called(1);
});
```

### Testing State with Data

```dart
test('Given notifications with audio enabled and not muted, '
    'when building initial state, '
    'then should process audio and return populated state', () async {
  // Arrange
  const testNotifications = [
    NotificationData(
      idleTimeOut: 300,
      appType: 1,
      audioStatus: 1,
      url: 'https://test.com',
      refName: 'TestRef',
      menuName: 'TestMenu',
      userId: 'user1',
      userName: 'Test User',
    ),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => testNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );
  when(
    mockNotificationService.processAudioForNotifications(
      notificationList: testNotifications,
      isAudioEnabled: true,
      shouldPlayAudio: true,
      wasRadioPlaying: false,
      currentPlayer: null,
      isAudioMuted: false,
    ),
  ).thenAnswer(
    (_) async => (
      audioFiles: ['TestRef'],
      fileIndex: 0,
      wasRadioPlaying: false,
      player: mockAudioPlayer,
    ),
  );

  final container = createContainer();

  // Act
  final notifier = container.read(notificationNotifierProvider.notifier);
  final state = await notifier.future;

  // Assert
  expect(state.notifications, testNotifications);
  expect(state.isAudioEnabled, true);
  expect(state.isAudioMuted, false);
  expect(state.shouldPlayAudio, true);
  expect(state.audioFileNames, ['TestRef']);
  expect(state.userList, ['user1']);
  expect(state.audioFileIndex, 0);
  expect(state.wasRadioPlaying, false);
  expect(state.audioPlayer, mockAudioPlayer);
});
```

## Testing State Mutations

### Testing Simple State Updates

```dart
test('Given valid state, '
    'when setShouldPlayAudio is called with true, '
    'then should update shouldPlayAudio to true', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Act
  notifier.setShouldPlayAudio(value: true);

  // Assert
  final state = container.read(notificationNotifierProvider).value!;
  expect(state.shouldPlayAudio, true);
});
```

### Testing Async State Updates (refreshState)

```dart
test('Given valid service responses, '
    'when refreshState is called, '
    'then should update state with fresh data', () async {
  // Arrange
  const initialNotifications = [
    NotificationData(refName: 'Initial', userId: 'user1'),
  ];
  const updatedNotifications = [
    NotificationData(refName: 'Updated', userId: 'user2'),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => initialNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Update mock for refreshState
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => updatedNotifications);
  when(
    mockNotificationService.processAudioForNotifications(
      notificationList: updatedNotifications,
      isAudioEnabled: true,
      shouldPlayAudio: true,
      wasRadioPlaying: false,
      currentPlayer: null,
      isAudioMuted: false,
    ),
  ).thenAnswer(
    (_) async => (
      audioFiles: ['Updated'],
      fileIndex: 0,
      wasRadioPlaying: false,
      player: mockAudioPlayer,
    ),
  );

  // Act
  await notifier.refreshState();

  // Assert
  final state = container.read(notificationNotifierProvider).value!;
  expect(state.notifications, updatedNotifications);
  expect(state.userList, ['user2']);
  expect(state.audioFileNames, ['Updated']);

  verify(mockNotificationService.fetchNotifications()).called(2); // Initial + refresh
});
```

## Testing Error Handling

### Testing AsyncError State

```dart
test('Given service throws exception, '
    'when refreshState is called, '
    'then should set state to AsyncError', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Setup exception for refreshState
  when(mockNotificationService.fetchNotifications()).thenThrow(Exception('Network error'));

  // Act
  await notifier.refreshState();

  // Assert
  final asyncState = container.read(notificationNotifierProvider);
  expect(asyncState.hasError, true);
  expect(asyncState.error.toString(), contains('Network error'));
});
```

### Testing Error Propagation

```dart
test('Given audio processing throws exception, '
    'when building initial state with audio enabled, '
    'then should propagate error', () async {
  // Arrange
  const testNotifications = [
    NotificationData(audioStatus: 1, refName: 'TestRef'),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => testNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );
  when(
    mockNotificationService.processAudioForNotifications(
      notificationList: anyNamed('notificationList'),
      isAudioEnabled: anyNamed('isAudioEnabled'),
      shouldPlayAudio: anyNamed('shouldPlayAudio'),
      wasRadioPlaying: anyNamed('wasRadioPlaying'),
      currentPlayer: anyNamed('currentPlayer'),
      isAudioMuted: anyNamed('isAudioMuted'),
    ),
  ).thenThrow(Exception('Audio processing failed'));

  final container = createContainer();

  // Act & Assert
  expect(() async {
    final notifier = container.read(notificationNotifierProvider.notifier);
    await notifier.future;
  }, throwsA(isA<Exception>()));
});
```

## Testing Provider Dependencies

### Overriding Service Dependencies

```dart
final container = createContainer(overrides: [
  // Override the service provider with a mock
  notificationServiceProvider.overrideWith((ref) => mockNotificationService),

  // Override repository provider
  notificationRepositoryProvider.overrideWith((ref) => mockRepository),

  // Can override multiple providers
  loggerProvider.overrideWith((ref) => mockLogger),
]);
```

### Testing Provider Reads

```dart
test('Given provider dependencies, '
    'when provider is built, '
    'then should read dependencies correctly', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer(overrides: [
    notificationServiceProvider.overrideWith((ref) => mockNotificationService),
  ]);

  // Act
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Assert
  verify(mockNotificationService.fetchNotifications()).called(1);
  verify(mockNotificationService.getAudioConfiguration()).called(1);
});
```

## Testing Provider Lifecycle

### Testing ref.onDispose

```dart
test('Given provider is disposed, '
    'when container is disposed, '
    'then should unsubscribe from notifications and dispose audio', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );
  when(mockNotificationService.disposeAudioPlayer(any)).thenAnswer((_) async {});

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Set up a player in state
  notifier.state = AsyncData(
    notifier.state.value!.copyWith(audioPlayer: mockAudioPlayer),
  );

  // Act - Dispose the container to trigger ref.onDispose
  container.dispose();

  // Assert - Verify unsubscribe calls
  verify(
    mockNotificationCenter.unsubscribe(
      channel: AppConstants.notificationAudioChannel,
      observer: notifier,
    ),
  ).called(1);

  verify(
    mockNotificationCenter.unsubscribe(
      channel: AppConstants.notificationUpdateChannel,
      observer: notifier,
    ),
  ).called(1);
});
```

## Testing Complex State Transitions

### Testing State with Conditional Logic

```dart
test('Given audio config changes to muted during refresh, '
    'when refreshState is called, '
    'then should disable audio and keep existing player', () async {
  // Arrange
  const testNotifications = [
    NotificationData(refName: 'TestRef', userId: 'user1', audioStatus: 1),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => testNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );
  when(mockNotificationService.disposeAudioPlayer(any)).thenAnswer((_) async {});

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Set up existing audio player in state
  notifier.state = AsyncData(
    notifier.state.value!.copyWith(audioPlayer: mockAudioPlayer),
  );

  // Change audio config to muted for refresh
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: true, isAudioEnabled: true),
  );

  // Act
  await notifier.refreshState();

  // Assert
  final state = container.read(notificationNotifierProvider).value!;
  expect(state.isAudioMuted, true);
  expect(state.shouldPlayAudio, false);
  expect(state.audioFileNames, isEmpty);
});
```

### Testing State with Resource Cleanup

```dart
test('Given existing audio player and new notifications with audio, '
    'when refreshState is called, '
    'then should dispose old player and create new one', () async {
  // Arrange
  const initialNotifications = [
    NotificationData(refName: 'Initial', userId: 'user1', audioStatus: 1),
  ];
  const updatedNotifications = [
    NotificationData(refName: 'Updated1', userId: 'user2', audioStatus: 1),
    NotificationData(refName: 'Updated2', userId: 'user3', audioStatus: 1),
  ];

  final mockAudioPlayer2 = MockAudioPlayer();

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => initialNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );
  when(mockNotificationService.disposeAudioPlayer(any)).thenAnswer((_) async {});

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Set up existing audio player
  notifier.state = AsyncData(
    notifier.state.value!.copyWith(
      audioPlayer: mockAudioPlayer,
      wasRadioPlaying: true,
    ),
  );

  // Update for refreshState with new notifications
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => updatedNotifications);
  when(
    mockNotificationService.processAudioForNotifications(
      notificationList: updatedNotifications,
      isAudioEnabled: true,
      shouldPlayAudio: true,
      wasRadioPlaying: true,
      currentPlayer: null,
      isAudioMuted: false,
    ),
  ).thenAnswer(
    (_) async => (
      audioFiles: ['Updated1', 'Updated2'],
      fileIndex: 1,
      wasRadioPlaying: false,
      player: mockAudioPlayer2,
    ),
  );

  // Act
  await notifier.refreshState();

  // Assert
  final state = container.read(notificationNotifierProvider).value!;
  expect(state.notifications, updatedNotifications);
  expect(state.audioFileNames, ['Updated1', 'Updated2']);
  expect(state.audioFileIndex, 1);
  expect(state.wasRadioPlaying, false);
  expect(state.audioPlayer, mockAudioPlayer2);
  expect(state.userList, ['user2', 'user3']);

  // Verify the existing player was disposed
  verify(mockNotificationService.disposeAudioPlayer(mockAudioPlayer)).called(1);
});
```

## Testing Notification Subscriptions

### Testing Channel Subscriptions

```dart
test('Given notification audio channel update, '
    'when onNotification is triggered, '
    'then should refresh audio configuration', () async {
  // Arrange
  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => []);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: false, isAudioEnabled: true),
  );

  final container = createContainer();
  final notifier = container.read(notificationNotifierProvider.notifier);
  await notifier.future;

  // Update audio config for callback
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: true, isAudioEnabled: false),
  );

  // Act - Manually trigger the audio configuration update
  // This simulates what would happen in the subscription callback
  final audioConfig = await mockNotificationService.getAudioConfiguration();
  notifier.state = AsyncData(
    notifier.state.value!.copyWith(
      isAudioEnabled: audioConfig.isAudioEnabled,
      isAudioMuted: audioConfig.isAudioMuted,
    ),
  );

  // Assert
  final state = container.read(notificationNotifierProvider).value!;
  expect(state.isAudioMuted, true);
  expect(state.isAudioEnabled, false);
});
```

## Testing Edge Cases

### Testing Empty or Null Data

```dart
test('Given empty userId values in notifications, '
    'when building state, '
    'then should include empty strings in userList', () async {
  // Arrange
  const testNotifications = [
    NotificationData(userId: 'user1', userName: 'User One'),
    NotificationData(userName: 'Empty User'), // Empty userId
    NotificationData(userName: 'No ID User'),
    NotificationData(userId: 'user2', userName: 'User Two'),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => testNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: true, isAudioEnabled: true),
  );

  final container = createContainer();

  // Act
  final notifier = container.read(notificationNotifierProvider.notifier);
  final state = await notifier.future;

  // Assert
  expect(state.userList, ['user1', '', 'user2']);
  expect(state.userList.length, 3);
});
```

### Testing State Consistency

```dart
test('Given multiple notifications with different users, '
    'when building initial state, '
    'then should extract unique user list', () async {
  // Arrange
  const testNotifications = [
    NotificationData(userId: 'user1', userName: 'User One'),
    NotificationData(userId: 'user2', userName: 'User Two'),
    NotificationData(userId: 'user1', userName: 'User One'), // Duplicate
    NotificationData(userId: 'user3', userName: 'User Three'),
  ];

  when(mockNotificationService.fetchNotifications()).thenAnswer((_) async => testNotifications);
  when(mockNotificationService.getAudioConfiguration()).thenAnswer(
    (_) async => (isAudioMuted: true, isAudioEnabled: true),
  );

  final container = createContainer();

  // Act
  final notifier = container.read(notificationNotifierProvider.notifier);
  final state = await notifier.future;

  // Assert
  expect(state.userList, containsAll(['user1', 'user2', 'user3']));
  expect(state.userList.length, 3); // Should be unique
});
```

## Riverpod Testing Patterns Summary

### Key Principles

1. Never mock providers - override dependencies
2. Use `createContainer()` with overrides
3. Test initial state (build method)
4. Test state mutations
5. Test async state updates
6. Test error handling (AsyncError)
7. Test lifecycle (ref.onDispose)
8. Test subscriptions and notifications
9. Verify service method calls
10. Test edge cases and null handling

### Common Setup Pattern

```dart
late MockINotificationService mockNotificationService;
late MockILogger mockLogger;

setUp(() {
  mockNotificationService = MockINotificationService();
  mockLogger = MockILogger();

  GetIt.I.reset();
  GetIt.I
    ..registerSingleton<INotificationService>(mockNotificationService)
    ..registerSingleton<ILogger>(mockLogger);
});

tearDown(() {
  GetIt.I.reset();
});
```

### Common Test Pattern

```dart
test('Given [condition], when [action], then [expected result]', () async {
  // Arrange
  when(mockService.method()).thenAnswer((_) async => mockData);
  final container = createContainer();
  final notifier = container.read(provider.notifier);
  await notifier.future;

  // Act
  await notifier.performAction();

  // Assert
  final state = container.read(provider).value!;
  expect(state.property, expectedValue);
  verify(mockService.method()).called(1);
});
```
