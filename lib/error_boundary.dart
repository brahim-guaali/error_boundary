/// A robust error boundary widget for Flutter.
///
/// This package provides an [ErrorBoundary] widget that catches and handles
/// errors gracefully, preventing app crashes and providing fallback UI.
///
/// ## Features
///
/// - Catch widget build errors
/// - Catch async errors (Futures, Streams) within the boundary
/// - Configurable recovery strategies (retry, reset)
/// - Pluggable error reporters
/// - Nested boundaries with error bubbling
/// - Dev mode with detailed error display
/// - Testing utilities
///
/// ## Basic Usage
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   fallback: (error, retry) => ErrorFallback(onRetry: retry),
/// )
/// ```
///
/// ## With Recovery Strategy
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   recovery: RecoveryStrategy.retry(maxAttempts: 3),
///   fallback: (error, retry) => ErrorFallback(onRetry: retry),
/// )
/// ```
///
/// ## Extension Syntax
///
/// ```dart
/// MyWidget().withErrorBoundary(
///   fallback: (error, retry) => Text('Error: $error'),
/// )
/// ```
library error_boundary;

export 'src/error_boundary_widget.dart';
export 'src/error_info.dart';
export 'src/recovery_strategy.dart';
export 'src/reporters/reporter.dart';
export 'src/reporters/console_reporter.dart';
export 'src/reporters/sentry_reporter.dart';
export 'src/reporters/firebase_crashlytics_reporter.dart';
export 'src/testing/test_helpers.dart';
