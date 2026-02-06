import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../error_info.dart';
import 'reporter.dart';

/// An [ErrorReporter] that logs errors to the console.
///
/// This reporter is useful for development and debugging. In production,
/// you should use a more robust reporter like Sentry or Firebase Crashlytics.
///
/// ## Example
///
/// ```dart
/// ErrorBoundary(
///   reporters: [ConsoleReporter()],
///   child: MyWidget(),
/// )
/// ```
class ConsoleReporter implements ErrorReporter {
  /// Creates a console reporter.
  ///
  /// [includeStackTrace] - Whether to include stack traces in logs (default: true in debug mode).
  /// [minSeverity] - Minimum severity level to report (default: low).
  ConsoleReporter({
    bool? includeStackTrace,
    this.minSeverity = ErrorSeverity.low,
  }) : includeStackTrace = includeStackTrace ?? kDebugMode;

  /// Whether to include stack traces in log output.
  final bool includeStackTrace;

  /// Minimum severity level to report.
  final ErrorSeverity minSeverity;

  String? _userId;
  final Map<String, dynamic> _customKeys = {};

  @override
  Future<void> report(ErrorInfo info) async {
    if (info.severity.index < minSeverity.index) return;

    final buffer = StringBuffer()
      ..writeln('=' * 60)
      ..writeln('ERROR BOUNDARY CAUGHT ERROR')
      ..writeln('=' * 60)
      ..writeln('Error: ${info.error}')
      ..writeln('Type: ${info.type.name}')
      ..writeln('Severity: ${info.severity.name}')
      ..writeln('Timestamp: ${info.effectiveTimestamp.toIso8601String()}');

    if (info.source != null) {
      buffer.writeln('Source: ${info.source}');
    }

    if (_userId != null) {
      buffer.writeln('User: $_userId');
    }

    if (_customKeys.isNotEmpty) {
      buffer.writeln('Custom Data: $_customKeys');
    }

    if (info.context.isNotEmpty) {
      buffer.writeln('Context: ${info.context}');
    }

    if (includeStackTrace) {
      buffer
        ..writeln('-' * 60)
        ..writeln('Stack Trace:')
        ..writeln(info.stackTrace);
    }

    buffer.writeln('=' * 60);

    developer.log(
      buffer.toString(),
      name: 'ErrorBoundary',
      error: info.error,
      stackTrace: includeStackTrace ? info.stackTrace : null,
      level: _severityToLogLevel(info.severity),
    );
  }

  @override
  void setUserIdentifier(String? userId) {
    _userId = userId;
  }

  @override
  void setCustomKey(String key, dynamic value) {
    if (value == null) {
      _customKeys.remove(key);
    } else {
      _customKeys[key] = value;
    }
  }

  int _severityToLogLevel(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.low => 500, // FINE
      ErrorSeverity.medium => 800, // INFO
      ErrorSeverity.high => 900, // WARNING
      ErrorSeverity.critical => 1000, // SEVERE
    };
  }
}
