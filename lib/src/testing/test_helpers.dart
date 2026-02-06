import 'package:flutter/widgets.dart';

import '../error_boundary_widget.dart';
import '../error_info.dart';

/// Testing utilities for [ErrorBoundary].
///
/// These helpers make it easy to test error boundary behavior in widget tests.
///
/// ## Example
///
/// ```dart
/// testWidgets('shows fallback on error', (tester) async {
///   final tracker = ErrorTracker();
///
///   await tester.pumpWidget(
///     MaterialApp(
///       home: ErrorBoundary(
///         onError: tracker.onError,
///         child: ThrowingWidget(),
///       ),
///     ),
///   );
///
///   expect(tracker.errors, hasLength(1));
///   expect(tracker.lastError?.error, isA<MyException>());
/// });
/// ```
class ErrorTracker {
  /// List of all errors caught by the tracker.
  final List<ErrorInfo> errors = [];

  /// The most recent error caught, or null if no errors.
  ErrorInfo? get lastError => errors.isEmpty ? null : errors.last;

  /// Whether any errors have been caught.
  bool get hasErrors => errors.isNotEmpty;

  /// Number of errors caught.
  int get errorCount => errors.length;

  /// Callback to use with [ErrorBoundary.onError].
  void onError(Object error, StackTrace stackTrace) {
    errors.add(ErrorInfo(
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    ));
  }

  /// Clears all tracked errors.
  void clear() => errors.clear();
}

/// A widget that throws an error during build.
///
/// Useful for testing error boundary behavior.
///
/// ```dart
/// ErrorBoundary(
///   child: ThrowingWidget(error: MyException('test')),
/// )
/// ```
class ThrowingWidget extends StatelessWidget {
  /// Creates a widget that throws during build.
  const ThrowingWidget({
    super.key,
    this.error,
    this.throwAfterFrames = 0,
  });

  /// The error to throw. Defaults to a generic [Exception].
  final Object? error;

  /// Number of frames to wait before throwing.
  ///
  /// Useful for testing errors that occur after initial build.
  final int throwAfterFrames;

  static int _frameCount = 0;

  @override
  Widget build(BuildContext context) {
    if (_frameCount >= throwAfterFrames) {
      _frameCount = 0;
      throw error ?? Exception('Test error from ThrowingWidget');
    }
    _frameCount++;
    return const SizedBox.shrink();
  }
}

/// A widget that throws an async error.
///
/// Useful for testing async error catching in error boundaries.
class AsyncThrowingWidget extends StatefulWidget {
  /// Creates a widget that throws an async error.
  const AsyncThrowingWidget({
    super.key,
    this.error,
    this.delay = Duration.zero,
  });

  /// The error to throw. Defaults to a generic [Exception].
  final Object? error;

  /// Delay before throwing the error.
  final Duration delay;

  @override
  State<AsyncThrowingWidget> createState() => _AsyncThrowingWidgetState();
}

class _AsyncThrowingWidgetState extends State<AsyncThrowingWidget> {
  @override
  void initState() {
    super.initState();
    _throwAsync();
  }

  Future<void> _throwAsync() async {
    await Future.delayed(widget.delay);
    throw widget.error ?? Exception('Async test error');
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Extension for testing [ErrorBoundary] widgets.
extension ErrorBoundaryTestExtension on ErrorBoundary {
  /// Creates a test-friendly version of this error boundary.
  ///
  /// The returned boundary tracks errors in the provided [tracker].
  ErrorBoundary withTracker(ErrorTracker tracker) {
    return ErrorBoundary(
      key: key,
      fallback: fallback,
      onError: (error, stack) {
        tracker.onError(error, stack);
        onError?.call(error, stack);
      },
      reporters: reporters,
      recovery: recovery,
      shouldRethrow: shouldRethrow,
      catchAsync: catchAsync,
      devMode: devMode,
      child: child,
    );
  }
}

/// Mixin that provides error boundary testing helpers.
///
/// Add this mixin to your test class for convenient access to testing utilities.
///
/// ```dart
/// void main() {
///   group('MyWidget', () {
///     late ErrorTracker tracker;
///
///     setUp(() {
///       tracker = ErrorTracker();
///     });
///
///     testWidgets('handles errors', (tester) async {
///       // Use tracker in tests
///     });
///   });
/// }
/// ```
mixin ErrorBoundaryTestHelpers {
  /// Creates a new error tracker.
  ErrorTracker createErrorTracker() => ErrorTracker();

  /// Creates a widget that throws during build.
  Widget createThrowingWidget([Object? error]) => ThrowingWidget(error: error);

  /// Creates a widget that throws asynchronously.
  Widget createAsyncThrowingWidget([Object? error, Duration? delay]) =>
      AsyncThrowingWidget(error: error, delay: delay ?? Duration.zero);
}
