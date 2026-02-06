# error_boundary

[![pub package](https://img.shields.io/pub/v/error_boundary.svg)](https://pub.dev/packages/error_boundary)
[![CI](https://github.com/brahim-guaali/error_boundary/actions/workflows/ci.yml/badge.svg)](https://github.com/brahim-guaali/error_boundary/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/brahim-guaali/error_boundary/branch/main/graph/badge.svg)](https://codecov.io/gh/brahim-guaali/error_boundary)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

A robust error boundary widget for Flutter that catches and handles errors gracefully, preventing app crashes and providing fallback UI.

Inspired by React's Error Boundaries, this package brings the same pattern to Flutter with additional features like recovery strategies, async error catching, and pluggable error reporters.

## Features

- **Catch build errors** - Prevent widget build failures from crashing your app
- **Catch async errors** - Optionally catch errors from Futures and Streams within the boundary
- **Custom fallback UI** - Show user-friendly error screens instead of red error screens
- **Recovery strategies** - Automatically retry, reset, or use custom recovery logic
- **Error reporting** - Plug in Sentry, Crashlytics, or any custom reporter
- **Nested boundaries** - Isolate errors to specific parts of your widget tree
- **Dev mode** - Show detailed error info in development, clean UI in production
- **Testing utilities** - Helpers for testing error boundary behavior

## Installation

```yaml
dependencies:
  error_boundary: ^0.1.0
```

## Quick Start

### Basic Usage

Wrap any widget that might throw errors:

```dart
ErrorBoundary(
  child: MyWidget(),
)
```

### Custom Fallback UI

```dart
ErrorBoundary(
  fallback: (error, retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('Error: ${error.message}'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: retry,
          child: const Text('Retry'),
        ),
      ],
    ),
  ),
  child: MyWidget(),
)
```

### Extension Syntax

For cleaner code, use the extension method:

```dart
MyWidget().withErrorBoundary(
  fallback: (error, retry) => Text('Something went wrong'),
)
```

## Recovery Strategies

### No Recovery (Default)

Shows fallback until manual retry:

```dart
ErrorBoundary(
  recovery: const RecoveryStrategy.none(),
  child: MyWidget(),
)
```

### Auto-Retry

Automatically retry with exponential backoff:

```dart
ErrorBoundary(
  recovery: const RecoveryStrategy.retry(
    maxAttempts: 3,
    delay: Duration(seconds: 1),
    backoff: true, // Exponential backoff
  ),
  child: MyWidget(),
)
```

### Reset

Completely rebuild the child widget tree:

```dart
ErrorBoundary(
  recovery: const RecoveryStrategy.reset(),
  child: MyWidget(),
)
```

### Custom Recovery

Implement your own recovery logic:

```dart
ErrorBoundary(
  recovery: RecoveryStrategy.custom(
    onRecover: () async {
      await clearCache();
      return true; // Return true to retry
    },
  ),
  child: MyWidget(),
)
```

## Error Reporting

### Console Reporter (Built-in)

Logs errors to the console with detailed information:

```dart
ErrorBoundary(
  reporters: [ConsoleReporter()],
  child: MyWidget(),
)
```

### Sentry Reporter (Built-in)

Send errors to [Sentry](https://sentry.io) for monitoring:

```dart
// 1. Add sentry_flutter to pubspec.yaml
// dependencies:
//   sentry_flutter: ^7.0.0

// 2. Initialize Sentry in main.dart
await SentryFlutter.init(
  (options) => options.dsn = 'YOUR_DSN',
  appRunner: () => runApp(MyApp()),
);

// 3. Use the reporter
ErrorBoundary(
  reporters: [
    SentryReporter(
      captureException: Sentry.captureException,
      configureScope: Sentry.configureScope,
    ),
  ],
  child: MyWidget(),
)
```

With filtering:

```dart
SentryReporter(
  captureException: Sentry.captureException,
  configureScope: Sentry.configureScope,
  beforeSend: (info) {
    // Skip non-critical errors
    if (info.severity == ErrorSeverity.low) return null;
    return info;
  },
  environment: 'production',
  release: '1.0.0',
)
```

### Firebase Crashlytics Reporter (Built-in)

Send errors to [Firebase Crashlytics](https://firebase.google.com/products/crashlytics):

```dart
// 1. Add firebase_crashlytics to pubspec.yaml
// dependencies:
//   firebase_crashlytics: ^3.0.0

// 2. Initialize Firebase in main.dart
await Firebase.initializeApp();

// 3. Use the reporter
final crashlytics = FirebaseCrashlytics.instance;

ErrorBoundary(
  reporters: [
    FirebaseCrashlyticsReporter(
      recordError: crashlytics.recordError,
      setCustomKey: crashlytics.setCustomKey,
      setUserIdentifier: crashlytics.setUserIdentifier,
      log: crashlytics.log,
    ),
  ],
  child: MyWidget(),
)
```

### Custom Reporter

Implement `ErrorReporter` for your own error tracking service:

```dart
class MyAnalyticsReporter implements ErrorReporter {
  @override
  Future<void> report(ErrorInfo info) async {
    await myAnalytics.trackError(
      error: info.error.toString(),
      stackTrace: info.stackTrace.toString(),
      severity: info.severity.name,
    );
  }

  @override
  void setUserIdentifier(String? userId) {
    myAnalytics.setUserId(userId);
  }

  @override
  void setCustomKey(String key, dynamic value) {
    myAnalytics.setProperty(key, value);
  }
}
```

### Multiple Reporters

Use multiple reporters simultaneously:

```dart
ErrorBoundary(
  reporters: [
    ConsoleReporter(),                    // Dev logging
    SentryReporter(...),                  // Error monitoring
    FirebaseCrashlyticsReporter(...),     // Crash reporting
  ],
  child: MyWidget(),
)
```

Or use `CompositeReporter`:

```dart
final reporter = CompositeReporter([
  ConsoleReporter(),
  SentryReporter(...),
]);

ErrorBoundary(
  reporters: [reporter],
  child: MyWidget(),
)
```

## Nested Boundaries

Error boundaries can be nested to isolate errors:

```dart
ErrorBoundary(
  onError: (e, s) => print('Outer caught: $e'),
  child: Column(
    children: [
      SafeWidget(),
      ErrorBoundary(
        child: DangerousWidget(), // Errors here won't affect SafeWidget
      ),
    ],
  ),
)
```

### Error Bubbling

Use `shouldRethrow` to bubble errors up to parent boundaries:

```dart
ErrorBoundary(
  shouldRethrow: (error) => error is CriticalError,
  child: MyWidget(),
)
```

## Async Error Catching

By default, errors in Futures and Streams within the boundary are caught:

```dart
ErrorBoundary(
  catchAsync: true, // Default
  child: MyAsyncWidget(),
)
```

Disable if you handle async errors differently:

```dart
ErrorBoundary(
  catchAsync: false,
  child: MyWidget(),
)
```

## Testing

The package includes testing utilities:

```dart
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows fallback on error', (tester) async {
    final tracker = ErrorTracker();

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          onError: tracker.onError,
          child: ThrowingWidget(error: Exception('Test')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tracker.hasErrors, isTrue);
    expect(tracker.lastError?.message, contains('Test'));
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
```

### Test Helpers

- `ErrorTracker` - Captures errors for assertions
- `ThrowingWidget` - Widget that throws during build
- `AsyncThrowingWidget` - Widget that throws async errors

## API Reference

### ErrorBoundary

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | required | Widget to wrap |
| `fallback` | `FallbackBuilder?` | null | Custom fallback UI builder |
| `onError` | `ErrorCallback?` | null | Called when error occurs |
| `reporters` | `List<ErrorReporter>` | `[]` | Error reporters |
| `recovery` | `RecoveryStrategy` | `none()` | Recovery strategy |
| `shouldRethrow` | `ShouldRethrow?` | null | Whether to bubble errors |
| `catchAsync` | `bool` | `true` | Catch async errors |
| `devMode` | `bool?` | `kDebugMode` | Show detailed errors |

### ErrorInfo

| Property | Type | Description |
|----------|------|-------------|
| `error` | `Object` | The error object |
| `stackTrace` | `StackTrace` | Stack trace |
| `severity` | `ErrorSeverity` | low, medium, high, critical |
| `type` | `ErrorType` | build, runtime, async, etc. |
| `source` | `String?` | Error source identifier |
| `timestamp` | `DateTime` | When error occurred |
| `context` | `Map<String, dynamic>` | Additional context |

## Contributing

Contributions are welcome! Please read our [contributing guidelines](https://github.com/brahim-guaali/error_boundary/blob/main/CONTRIBUTING.md) before submitting a PR.

## License

BSD 3-Clause License - see [LICENSE](LICENSE) for details.
