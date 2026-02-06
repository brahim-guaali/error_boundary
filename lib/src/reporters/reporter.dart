import '../error_info.dart';

/// Interface for reporting errors to external services.
///
/// Implement this interface to create custom error reporters for services
/// like Sentry, Firebase Crashlytics, or your own backend.
///
/// ## Example
///
/// ```dart
/// class MyErrorReporter implements ErrorReporter {
///   @override
///   Future<void> report(ErrorInfo info) async {
///     await myAnalyticsService.trackError(
///       error: info.error,
///       stackTrace: info.stackTrace,
///       severity: info.severity.name,
///     );
///   }
///
///   @override
///   void setUserIdentifier(String? userId) {
///     myAnalyticsService.setUserId(userId);
///   }
///
///   @override
///   void setCustomKey(String key, dynamic value) {
///     myAnalyticsService.setCustomKey(key, value);
///   }
/// }
/// ```
abstract interface class ErrorReporter {
  /// Reports an error to the external service.
  ///
  /// This method should not throw - any errors during reporting should be
  /// caught and handled internally.
  Future<void> report(ErrorInfo info);

  /// Sets the user identifier for error reports.
  ///
  /// Pass `null` to clear the user identifier.
  void setUserIdentifier(String? userId);

  /// Sets a custom key-value pair for error reports.
  ///
  /// This can be used to attach additional context to all future error reports.
  void setCustomKey(String key, dynamic value);
}

/// A reporter that combines multiple reporters.
///
/// Errors are reported to all reporters in parallel.
class CompositeReporter implements ErrorReporter {
  /// Creates a composite reporter from multiple reporters.
  const CompositeReporter(this.reporters);

  /// The list of reporters to delegate to.
  final List<ErrorReporter> reporters;

  @override
  Future<void> report(ErrorInfo info) async {
    await Future.wait(
      reporters.map((r) => r.report(info)),
      eagerError: false,
    );
  }

  @override
  void setUserIdentifier(String? userId) {
    for (final reporter in reporters) {
      reporter.setUserIdentifier(userId);
    }
  }

  @override
  void setCustomKey(String key, dynamic value) {
    for (final reporter in reporters) {
      reporter.setCustomKey(key, value);
    }
  }
}
