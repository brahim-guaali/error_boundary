import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:error_boundary/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('renders child when no error occurs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('shows default fallback when triggerError is called',
        (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            child: const Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);

      // Trigger an error manually
      boundaryKey.currentState!.triggerError(Exception('Test error'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows custom fallback when triggerError is called',
        (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            fallback: (error, retry) => const Text('Custom Error'),
            child: const Text('Hello'),
          ),
        ),
      );

      boundaryKey.currentState!.triggerError(Exception('Test'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Error'), findsOneWidget);
    });

    testWidgets('calls onError when error is triggered', (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();
      Object? caughtError;
      StackTrace? caughtStack;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            onError: (error, stack) {
              caughtError = error;
              caughtStack = stack;
            },
            child: const Text('Hello'),
          ),
        ),
      );

      final testError = Exception('Test error');
      boundaryKey.currentState!.triggerError(testError);
      await tester.pumpAndSettle();

      expect(caughtError, testError);
      expect(caughtStack, isNotNull);
    });

    testWidgets('retry resets error state', (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            fallback: (error, retry) => ElevatedButton(
              onPressed: retry,
              child: const Text('Retry'),
            ),
            child: const Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);

      // Trigger error
      boundaryKey.currentState!.triggerError(Exception('Test'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('ErrorTracker captures triggered errors', (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();
      final tracker = ErrorTracker();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            onError: tracker.onError,
            child: const Text('Hello'),
          ),
        ),
      );

      boundaryKey.currentState!
          .triggerError(Exception('Tracked error'));
      await tester.pumpAndSettle();

      expect(tracker.hasErrors, isTrue);
      expect(tracker.errorCount, 1);
      expect(tracker.lastError?.error.toString(), contains('Tracked error'));
    });

    testWidgets('hasError returns correct state', (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            child: const Text('Hello'),
          ),
        ),
      );

      expect(boundaryKey.currentState!.hasError, isFalse);

      boundaryKey.currentState!.triggerError(Exception('Test'));
      await tester.pumpAndSettle();

      expect(boundaryKey.currentState!.hasError, isTrue);
    });

    testWidgets('reset clears error and rebuilds child', (tester) async {
      final boundaryKey = GlobalKey<ErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            key: boundaryKey,
            child: const Text('Hello'),
          ),
        ),
      );

      boundaryKey.currentState!.triggerError(Exception('Test'));
      await tester.pumpAndSettle();

      expect(boundaryKey.currentState!.hasError, isTrue);

      boundaryKey.currentState!.reset();
      await tester.pumpAndSettle();

      expect(boundaryKey.currentState!.hasError, isFalse);
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('ErrorInfo', () {
    test('creates with required parameters', () {
      final info = ErrorInfo(
        error: Exception('test'),
        stackTrace: StackTrace.current,
      );

      expect(info.error, isA<Exception>());
      expect(info.stackTrace, isNotNull);
      expect(info.severity, ErrorSeverity.medium);
      expect(info.type, ErrorType.unknown);
    });

    test('copyWith creates new instance', () {
      final info = ErrorInfo(
        error: Exception('test'),
        stackTrace: StackTrace.current,
      );

      final copied = info.copyWith(severity: ErrorSeverity.critical);

      expect(copied.severity, ErrorSeverity.critical);
      expect(copied.error, info.error);
    });

    test('message returns error string', () {
      final info = ErrorInfo(
        error: Exception('test message'),
        stackTrace: StackTrace.current,
      );

      expect(info.message, contains('test message'));
    });
  });

  group('RecoveryStrategy', () {
    test('none strategy', () {
      const strategy = RecoveryStrategy.none();
      expect(strategy, isA<NoRecovery>());
    });

    test('retry strategy with defaults', () {
      const strategy = RecoveryStrategy.retry();
      expect(strategy, isA<RetryRecovery>());

      final retry = strategy as RetryRecovery;
      expect(retry.maxAttempts, 3);
      expect(retry.delay, const Duration(seconds: 1));
      expect(retry.backoff, true);
    });

    test('retry strategy calculates backoff delay', () {
      const strategy = RetryRecovery(
        delay: Duration(seconds: 1),
        backoff: true,
      );

      expect(strategy.getDelayForAttempt(1), const Duration(seconds: 1));
      expect(strategy.getDelayForAttempt(2), const Duration(seconds: 2));
      expect(strategy.getDelayForAttempt(3), const Duration(seconds: 4));
    });

    test('reset strategy', () {
      const strategy = RecoveryStrategy.reset();
      expect(strategy, isA<ResetRecovery>());
    });

    test('custom strategy', () {
      final strategy = RecoveryStrategy.custom(
        onRecover: () async => true,
      );
      expect(strategy, isA<CustomRecovery>());
    });
  });

  group('ErrorBoundaryExtension', () {
    testWidgets('withErrorBoundary wraps widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Hello').withErrorBoundary(),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(ErrorBoundary), findsOneWidget);
    });
  });

  group('ConsoleReporter', () {
    test('respects minimum severity', () async {
      final reporter = ConsoleReporter(minSeverity: ErrorSeverity.high);

      // Should not throw for low severity
      await reporter.report(ErrorInfo(
        error: Exception('low'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.low,
      ));

      // Should not throw for high severity
      await reporter.report(ErrorInfo(
        error: Exception('high'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.high,
      ));
    });

    test('sets user identifier', () {
      final reporter = ConsoleReporter();
      reporter.setUserIdentifier('user-123');
      reporter.setUserIdentifier(null); // Should not throw
    });

    test('sets custom keys', () {
      final reporter = ConsoleReporter();
      reporter.setCustomKey('version', '1.0.0');
      reporter.setCustomKey('version', null); // Should remove key
    });
  });

  group('ErrorTracker', () {
    test('tracks multiple errors', () {
      final tracker = ErrorTracker();

      tracker.onError(Exception('Error 1'), StackTrace.current);
      tracker.onError(Exception('Error 2'), StackTrace.current);

      expect(tracker.errorCount, 2);
      expect(tracker.errors.length, 2);
    });

    test('clear removes all errors', () {
      final tracker = ErrorTracker();

      tracker.onError(Exception('Error'), StackTrace.current);
      expect(tracker.hasErrors, isTrue);

      tracker.clear();
      expect(tracker.hasErrors, isFalse);
      expect(tracker.errorCount, 0);
    });

    test('lastError returns most recent', () {
      final tracker = ErrorTracker();

      tracker.onError(Exception('First'), StackTrace.current);
      tracker.onError(Exception('Second'), StackTrace.current);

      expect(tracker.lastError?.error.toString(), contains('Second'));
    });
  });
}
