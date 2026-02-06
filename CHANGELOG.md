## 0.1.0

- Initial release
- `ErrorBoundary` widget with fallback UI support
- `ErrorInfo` class for structured error information
- `RecoveryStrategy` for configurable error recovery (retry, reset, none, custom)
- `ErrorReporter` interface for pluggable error reporting
- Built-in reporters:
  - `ConsoleReporter` - Development logging with severity filtering
  - `SentryReporter` - Sentry integration with tags, context, and filtering
  - `FirebaseCrashlyticsReporter` - Firebase Crashlytics integration with custom keys
  - `CompositeReporter` - Combine multiple reporters
- Zone-based async error catching
- Nested boundary support with error bubbling
- Dev mode with detailed error display
- Extension methods for clean syntax (`widget.withErrorBoundary()`)
- Testing utilities (`ErrorTracker`, `ThrowingWidget`, `AsyncThrowingWidget`)
