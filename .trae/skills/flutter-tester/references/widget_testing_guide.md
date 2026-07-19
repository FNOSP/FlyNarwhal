# Widget Testing Guide

This file provides comprehensive patterns for testing Flutter widgets in the Flutter application.

## Essential Widget Test Setup

### Always Set Screen Size

Prevent overflow errors by setting explicit screen dimensions:

```dart
testWidgets('Test description', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  // Your test code
});
```

### Create Test Widget Wrapper

```dart
Widget createTestWidget() => ProviderScope(
  child: MaterialApp(home: NotificationView()),
);

// Or with MockGoRouterProvider
Widget createTestWidget() => ProviderScope(
  child: MockGoRouterProvider(
    goRouter: fakeGoRouter,
    child: const MaterialApp(home: RegistrationView()),
  ),
);
```

## Finding Widgets with Keys

### Why Use Keys

Keys provide stable, reliable widget identification that won't break when:

- Text content changes
- Widget positions shift
- Multiple similar widgets exist
- Widget tree reorganizes

### Adding Keys to Source Widgets

```dart
// ❌ BAD - No key
ElevatedButton(
  onPressed: () {},
  child: const Text('Save'),
);

// ✅ GOOD - Has key
ElevatedButton(
  key: const Key('saveButton'),
  onPressed: () {},
  child: const Text('Save'),
);
```

### Using Keys in Tests

```dart
testWidgets('Given save button, When tapped, Then calls save action', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(createTestWidget());

  // Find by key
  await tester.tap(find.byKey(const Key('saveButton')));
  await tester.pumpAndSettle();

  // Verify action
  verify(mockService.saveData()).called(1);
});
```

### Common Key Naming Conventions

```dart
// Buttons
key: const Key('saveButton')
key: const Key('cancelButton')
key: const Key('submitButton')

// Input fields
key: const Key('emailTextField')
key: const Key('passwordTextField')

// Containers/Sections
key: const Key('headerSection')
key: const Key('footerSection')

// List items
key: Key('listItem_$index')
key: Key('notification_${notification.id}')
```

## User Interaction Patterns

### Tapping Widgets

```dart
// Tap by key
await tester.tap(find.byKey(const Key('saveButton')));
await tester.pump();

// Tap by text (less stable)
await tester.tap(find.text('Save'));
await tester.pump();

// Tap by type (when only one widget of this type exists)
await tester.tap(find.byType(ElevatedButton));
await tester.pump();
```

### Text Input

```dart
// Enter text into first TextField
await tester.enterText(find.byType(TextField).first, 'example.com');

// Enter text into specific TextField by key
await tester.enterText(find.byKey(const Key('domainTextField')), 'example.com');

// Enter text into second TextField
await tester.enterText(find.byType(TextField).at(1), '101');
```

### Scrolling

```dart
// Scroll widget into view
await tester.scrollUntilVisible(
  find.byKey(const Key('targetWidget')),
  500.0, // Scroll offset
);

// Drag to scroll
await tester.drag(
  find.byType(ListView),
  const Offset(0, -200), // Scroll down
);
await tester.pump();
```

## Async Widget Testing

### Testing Loading States

```dart
testWidgets('Shows loading indicator during async operation', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  final completer = Completer<RegistrationModel>();

  when(mockRepository.fetchData(any, any)).thenAnswer((_) => completer.future);

  await tester.pumpWidget(createTestWidget());

  await tester.enterText(find.byType(TextField).first, 'example.com');
  await tester.enterText(find.byType(TextField).at(1), '101');
  await tester.tap(find.text('Save'));
  await tester.pump(); // Trigger the state update

  // Assert loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Complete the async operation
  completer.complete(const RegistrationModel(status: 'success'));
  await tester.pump(); // Process the completion

  // Assert loaded state
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

### Using pumpAndSettle

```dart
// Wait for all animations and async operations to complete
await tester.pumpWidget(createTestWidget());
await tester.pumpAndSettle();

// Now widget is fully rendered and stable
expect(find.byType(MyWidget), findsOneWidget);
```

### Pump vs PumpAndSettle

- `pump()` - Advances one frame, triggers setState once
- `pumpAndSettle()` - Waits for all animations/async to complete
- `pump(duration)` - Advances by specific duration

```dart
// Use pump() for immediate state changes
await tester.tap(find.byKey(const Key('button')));
await tester.pump(); // Single frame advance

// Use pumpAndSettle() for animations/async
await tester.tap(find.byKey(const Key('button')));
await tester.pumpAndSettle(); // Wait for everything to settle
```

## Platform-Specific Widget Testing

### Testing iOS-Specific Widgets

```dart
testWidgets('SerialNumberWidget is shown on iOS platform', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  await tester.pumpWidget(createTestWidget());

  expect(find.byType(SerialNumberWidget), findsOneWidget);
  expect(find.byType(CupertinoButton), findsOneWidget);

  debugDefaultTargetPlatformOverride = null; // Always reset!
});
```

### Testing Android-Specific Widgets

```dart
testWidgets('Material widgets shown on Android', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  await tester.pumpWidget(createTestWidget());

  expect(find.byType(ElevatedButton), findsOneWidget);
  expect(find.byType(MaterialApp), findsOneWidget);

  debugDefaultTargetPlatformOverride = null;
});
```

### Group Platform Tests

```dart
group('Platform-Specific Tests', () {
  testWidgets('iOS specific behavior', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(createTestWidget());

    expect(find.byType(CupertinoButton), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android specific behavior', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(createTestWidget());

    expect(find.byType(ElevatedButton), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
});
```

## Widget State Validation

### Validating Text Content

```dart
// Exact match
expect(find.text('Welcome'), findsOneWidget);

// Contains text (use textContaining)
expect(find.textContaining('Welcome'), findsOneWidget);

// Multiple matches
expect(find.text('Item'), findsNWidgets(3));

// No matches
expect(find.text('Error'), findsNothing);
```

### Validating Widget Presence

```dart
// Widget exists
expect(find.byType(CircularProgressIndicator), findsOneWidget);

// Widget doesn't exist
expect(find.byType(ErrorWidget), findsNothing);

// Multiple widgets
expect(find.byType(ListTile), findsNWidgets(5));

// At least one
expect(find.byType(Card), findsWidgets);
```

### Validating Widget Properties

```dart
// Get widget and check properties
final button = tester.widget<ElevatedButton>(
  find.byKey(const Key('saveButton')),
);
expect(button.enabled, true);

// Check TextField value
final textField = tester.widget<TextField>(
  find.byKey(const Key('emailTextField')),
);
expect(textField.controller?.text, 'example@test.com');
```

## Testing Dialogs and Overlays

### Testing Dialog Appearance

```dart
testWidgets('Shows dialog when validation fails', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(createTestWidget());

  await tester.enterText(find.byType(TextField).first, '');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  expect(find.text('Please Enter Domain Name or IP Address.'), findsOneWidget);
});
```

### Dismissing Dialogs

```dart
testWidgets('Dialog can be dismissed', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(createTestWidget());

  // Show dialog
  await tester.tap(find.byKey(const Key('showDialogButton')));
  await tester.pumpAndSettle();

  expect(find.byType(AlertDialog), findsOneWidget);

  // Dismiss dialog
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  expect(find.byType(AlertDialog), findsNothing);
});
```

## Testing Navigation and Routing

### Testing GoRouter Navigation

```dart
testWidgets('Save button navigates to loading screen', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  final fakeGoRouter = FakeGoRouter();
  when(mockRouterManager.router).thenReturn(fakeGoRouter);

  const mockResponse = RegistrationModel(status: 'success');
  when(mockRepository.fetchRegistrationDetails('example.com', '101'))
      .thenAnswer((_) async => mockResponse);

  await tester.pumpWidget(
    ProviderScope(
      child: MockGoRouterProvider(
        goRouter: fakeGoRouter,
        child: const MaterialApp(home: RegistrationView()),
      ),
    ),
  );

  await tester.enterText(find.byType(TextField).first, 'example.com');
  await tester.enterText(find.byType(TextField).at(1), '101');
  await tester.tap(find.text('Save'));
  await tester.pump();

  verify(fakeGoRouter.go(AppRoute.loading.path, extra: anyNamed('extra'))).called(1);
});
```

### Testing PopScope (Back Navigation)

```dart
testWidgets('PopScope prevents back navigation when required', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    ProviderScope(
      child: MockGoRouterProvider(
        goRouter: fakeGoRouter,
        child: const MaterialApp(
          home: RegistrationView(
            isItFromLaunchScreen: true,
            isItFromHomeScreen: false,
          ),
        ),
      ),
    ),
  );

  final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
  await tester.runAsync(() async {
    await widgetsAppState.didPopRoute();
  });
  await tester.pump();

  verifyNever(fakeGoRouter.canPop());
});
```

## Testing Lifecycle Methods

### Testing initState

```dart
testWidgets('initState sets up initial state correctly', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  when(mockService.isPlaying).thenReturn(true);
  when(mockService.pause()).thenAnswer((_) async {});

  await tester.pumpWidget(createTestWidget());

  // Ensure initState and ALL its async work completes
  await tester.pumpAndSettle();

  // Verify initState behavior
  verify(mockService.pause()).called(1);
});
```

### Testing dispose

```dart
testWidgets('dispose cleans up resources', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  when(mockRadioService.isRadioPlaying).thenReturn(true);
  when(mockRadioService.pauseAudioPlayer()).thenAnswer((_) async {});
  when(mockRadioService.resumeAudioPlayer()).thenAnswer((_) async {});

  await tester.pumpWidget(createTestWidget());
  await tester.pumpAndSettle();

  // Trigger dispose by pumping a different widget
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  // Verify cleanup
  verify(mockRadioService.pauseAudioPlayer()).called(1);
  verify(mockRadioService.resumeAudioPlayer()).called(1);
});
```

## Common Widget Testing Patterns

### Testing Conditional Rendering

```dart
testWidgets('Shows widget A when condition is true', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  global_variables.appCommunicationStatus = 3;

  await tester.pumpWidget(createTestWidget());

  expect(find.byType(DefaultCarouselWidget), findsOneWidget);
  expect(find.byType(ImageWidget), findsNothing);
});

testWidgets('Shows widget B when condition is false', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  global_variables.appCommunicationStatus = 1;

  await tester.pumpWidget(createTestWidget());

  expect(find.byType(ImageWidget), findsOneWidget);
  expect(find.byType(DefaultCarouselWidget), findsNothing);
});
```

### Testing List Widgets

```dart
testWidgets('ListView displays all items', (tester) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;

  final items = ['Item 1', 'Item 2', 'Item 3'];
  when(mockService.getItems()).thenReturn(items);

  await tester.pumpWidget(createTestWidget());
  await tester.pumpAndSettle();

  for (final item in items) {
    expect(find.text(item), findsOneWidget);
  }
});
```

### Testing Form Validation

```dart
group('Form Validation', () {
  testWidgets('Shows error when email is empty', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createTestWidget());

    await tester.enterText(find.byKey(const Key('emailField')), '');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter an email'), findsOneWidget);
  });

  testWidgets('Shows error when email is invalid', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createTestWidget());

    await tester.enterText(find.byKey(const Key('emailField')), 'invalid');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('Submits when form is valid', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createTestWidget());

    await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    verify(mockService.submit('test@example.com')).called(1);
  });
});
```

## Widget Testing Checklist

Before submitting widget tests:

- [ ] Screen size set (1000x1000, DPR 1.0)
- [ ] Keys added to source widgets
- [ ] Keys used in find operations
- [ ] Both pump() and pumpAndSettle() used appropriately
- [ ] Async operations tested with Completer
- [ ] Loading states tested
- [ ] Error states tested
- [ ] Platform overrides reset (debugDefaultTargetPlatformOverride = null)
- [ ] Global state reset in tearDown
- [ ] GetIt reset in tearDown
- [ ] Widget interactions verified
- [ ] Navigation verified if applicable
