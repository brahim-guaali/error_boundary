import 'package:flutter_test/flutter_test.dart';

import 'package:error_boundary/error_boundary.dart';

void main() {
  group('SentryReporter', () {
    test('creates with default callbacks', () {
      final reporter = SentryReporter();
      expect(reporter, isNotNull);
    });

    test('reports errors with custom captureException', () async {
      Object? capturedError;
      StackTrace? capturedStack;

      final reporter = SentryReporter(
        captureException: (exception, {stackTrace, hint}) async {
          capturedError = exception;
          capturedStack = stackTrace;
        },
        configureScope: (callback) {},
      );

      final error = Exception('Test error');
      final stack = StackTrace.current;

      await reporter.report(ErrorInfo(
        error: error,
        stackTrace: stack,
      ));

      expect(capturedError, error);
      expect(capturedStack, stack);
    });

    test('filters errors with beforeSend', () async {
      var reportCount = 0;

      final reporter = SentryReporter(
        captureException: (exception, {stackTrace, hint}) async {
          reportCount++;
        },
        configureScope: (callback) {},
        beforeSend: (info) {
          if (info.severity == ErrorSeverity.low) return null;
          return info;
        },
      );

      // Low severity - should be filtered
      await reporter.report(ErrorInfo(
        error: Exception('Low'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.low,
      ));

      expect(reportCount, 0);

      // High severity - should be reported
      await reporter.report(ErrorInfo(
        error: Exception('High'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.high,
      ));

      expect(reportCount, 1);
    });

    test('sets user identifier', () {
      String? userId;

      final reporter = SentryReporter(
        configureScope: (callback) {
          callback(_MockScope(onSetUser: (user) {
            userId = user?['id'];
          }));
        },
      );

      reporter.setUserIdentifier('user-123');
      expect(userId, 'user-123');

      reporter.setUserIdentifier(null);
      expect(userId, isNull);
    });

    test('sets custom keys', () {
      final reporter = SentryReporter();

      reporter.setCustomKey('version', '1.0.0');
      reporter.setCustomKey('build', 42);
      reporter.setCustomKey('version', null); // Remove key
    });

    test('adds and removes tags', () {
      final reporter = SentryReporter();

      reporter.addTag('environment', 'production');
      reporter.removeTag('environment');
    });
  });

  group('FirebaseCrashlyticsReporter', () {
    test('creates with default callbacks', () {
      final reporter = FirebaseCrashlyticsReporter();
      expect(reporter, isNotNull);
    });

    test('reports errors with custom recordError', () async {
      Object? recordedError;
      StackTrace? recordedStack;
      String? recordedReason;
      bool? wasFatal;

      final reporter = FirebaseCrashlyticsReporter(
        recordError: (exception, stack, {reason, fatal = false}) async {
          recordedError = exception;
          recordedStack = stack;
          recordedReason = reason;
          wasFatal = fatal;
        },
        setCustomKey: (key, value) async {},
        log: (message) async {},
      );

      final error = Exception('Test error');
      final stack = StackTrace.current;

      await reporter.report(ErrorInfo(
        error: error,
        stackTrace: stack,
        severity: ErrorSeverity.medium,
      ));

      expect(recordedError, error);
      expect(recordedStack, stack);
      expect(recordedReason, contains('Test error'));
      expect(wasFatal, false);
    });

    test('marks critical errors as fatal', () async {
      bool? wasFatal;

      final reporter = FirebaseCrashlyticsReporter(
        recordError: (exception, stack, {reason, fatal = false}) async {
          wasFatal = fatal;
        },
        setCustomKey: (key, value) async {},
        log: (message) async {},
      );

      await reporter.report(ErrorInfo(
        error: Exception('Critical'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.critical,
      ));

      expect(wasFatal, true);
    });

    test('respects collection enabled check', () async {
      var reportCount = 0;

      final reporter = FirebaseCrashlyticsReporter(
        recordError: (exception, stack, {reason, fatal = false}) async {
          reportCount++;
        },
        setCustomKey: (key, value) async {},
        log: (message) async {},
        isCrashlyticsCollectionEnabled: () => false,
      );

      await reporter.report(ErrorInfo(
        error: Exception('Test'),
        stackTrace: StackTrace.current,
      ));

      expect(reportCount, 0);
    });

    test('sets user identifier', () async {
      String? userId;

      final reporter = FirebaseCrashlyticsReporter(
        setUserIdentifier: (identifier) async {
          userId = identifier;
        },
      );

      reporter.setUserIdentifier('user-456');
      expect(userId, 'user-456');

      reporter.setUserIdentifier(null);
      expect(userId, '');
    });

    test('sets custom keys', () async {
      final keys = <String, Object>{};

      final reporter = FirebaseCrashlyticsReporter(
        setCustomKey: (key, value) async {
          keys[key] = value;
        },
      );

      reporter.setCustomKey('version', '2.0.0');
      expect(keys['version'], '2.0.0');
    });

    test('logs messages', () async {
      final logs = <String>[];

      final reporter = FirebaseCrashlyticsReporter(
        log: (message) async {
          logs.add(message);
        },
      );

      await reporter.log('Test message');
      expect(logs, contains('Test message'));
    });
  });

  group('CompositeReporter', () {
    test('reports to all reporters', () async {
      var reporter1Called = false;
      var reporter2Called = false;

      final composite = CompositeReporter([
        _MockReporter(onReport: () => reporter1Called = true),
        _MockReporter(onReport: () => reporter2Called = true),
      ]);

      await composite.report(ErrorInfo(
        error: Exception('Test'),
        stackTrace: StackTrace.current,
      ));

      expect(reporter1Called, true);
      expect(reporter2Called, true);
    });

    test('sets user identifier on all reporters', () {
      var id1 = '';
      var id2 = '';

      final composite = CompositeReporter([
        _MockReporter(onSetUser: (id) => id1 = id ?? ''),
        _MockReporter(onSetUser: (id) => id2 = id ?? ''),
      ]);

      composite.setUserIdentifier('user-789');

      expect(id1, 'user-789');
      expect(id2, 'user-789');
    });

    test('sets custom key on all reporters', () {
      final keys1 = <String, dynamic>{};
      final keys2 = <String, dynamic>{};

      final composite = CompositeReporter([
        _MockReporter(onSetKey: (k, v) => keys1[k] = v),
        _MockReporter(onSetKey: (k, v) => keys2[k] = v),
      ]);

      composite.setCustomKey('app', 'test');

      expect(keys1['app'], 'test');
      expect(keys2['app'], 'test');
    });
  });
}

class _MockReporter implements ErrorReporter {
  _MockReporter({
    this.onReport,
    this.onSetUser,
    this.onSetKey,
  });

  final void Function()? onReport;
  final void Function(String?)? onSetUser;
  final void Function(String, dynamic)? onSetKey;

  @override
  Future<void> report(ErrorInfo info) async {
    onReport?.call();
  }

  @override
  void setUserIdentifier(String? userId) {
    onSetUser?.call(userId);
  }

  @override
  void setCustomKey(String key, dynamic value) {
    onSetKey?.call(key, value);
  }
}

class _MockScope {
  _MockScope({this.onSetUser});

  final void Function(Map<String, dynamic>?)? onSetUser;

  void setUser(Map<String, dynamic>? user) {
    onSetUser?.call(user);
  }

  void setTag(String key, String value) {}
  void setExtra(String key, dynamic value) {}
}
