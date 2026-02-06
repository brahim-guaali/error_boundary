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

    testWidgets('shows default fallback on error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            child: ThrowingWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows custom fallback on error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            fallback: (error, retry) => const Text('Custom Error'),
            child: ThrowingWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Error'), findsOneWidget);
    });

    testWidgets('calls onError when error occurs', (tester) async {
      Object? caughtError;
      StackTrace? caughtStack;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            onError: (error, stack) {
              caughtError = error;
              caughtStack = stack;
            },
            child: ThrowingWidget(error: Exception('Test error')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(caughtError, isA<Exception>());
      expect(caughtError.toString(), contains('Test error'));
      expect(caughtStack, isNotNull);
    });

    testWidgets('retry rebuilds child widget', (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            fallback: (error, retry) => ElevatedButton(
              onPressed: retry,
              child: const Text('Retry'),
            ),
            child: Builder(
              builder: (context) {
                buildCount++;
                if (buildCount == 1) {
                  throw Exception('First build fails');
                }
                return const Text('Success');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Success'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('ErrorTracker captures errors', (tester) async {
      final tracker = ErrorTracker();

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            onError: tracker.onError,
            child: ThrowingWidget(error: Exception('Tracked error')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tracker.hasErrors, isTrue);
      expect(tracker.errorCount, 1);
      expect(tracker.lastError?.error.toString(), contains('Tracked error'));
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
}
