import 'package:flutter/foundation.dart';

import '../error_info.dart';
import 'reporter.dart';

/// An [ErrorReporter] that sends errors to Firebase Crashlytics.
///
/// This reporter requires the `firebase_crashlytics` package to be installed.
///
/// ## Setup
///
/// 1. Add `firebase_crashlytics` to your `pubspec.yaml`:
///    ```yaml
///    dependencies:
///      firebase_crashlytics: ^3.0.0
///    ```
///
/// 2. Initialize Firebase in your app:
///    ```dart
///    await Firebase.initializeApp();
///    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
///    ```
///
/// 3. Use the reporter:
///    ```dart
///    ErrorBoundary(
///      reporters: [
///        FirebaseCrashlyticsReporter(
///          recordError: FirebaseCrashlytics.instance.recordError,
///          setCustomKey: FirebaseCrashlytics.instance.setCustomKey,
///          setUserIdentifier: FirebaseCrashlytics.instance.setUserIdentifier,
///          log: FirebaseCrashlytics.instance.log,
///        ),
///      ],
///      child: MyWidget(),
///    )
///    ```
///
/// ## Example with Instance
///
/// ```dart
/// final crashlytics = FirebaseCrashlytics.instance;
///
/// FirebaseCrashlyticsReporter.fromInstance(
///   recordError: crashlytics.recordError,
///   setCustomKey: crashlytics.setCustomKey,
///   setUserIdentifier: crashlytics.setUserIdentifier,
///   log: crashlytics.log,
/// )
/// ```
class FirebaseCrashlyticsReporter implements ErrorReporter {
  /// Creates a Firebase Crashlytics reporter.
  ///
  /// [recordError] - Function to record errors. Pass `FirebaseCrashlytics.instance.recordError`.
  ///
  /// [setCustomKey] - Function to set custom keys. Pass `FirebaseCrashlytics.instance.setCustomKey`.
  ///
  /// [setUserIdentifier] - Function to set user ID. Pass `FirebaseCrashlytics.instance.setUserIdentifier`.
  ///
  /// [log] - Function to log messages. Pass `FirebaseCrashlytics.instance.log`.
  ///
  /// [isCrashlyticsCollectionEnabled] - Optional function to check if collection is enabled.
  ///
  /// [beforeSend] - Optional callback to filter or modify errors before sending.
  FirebaseCrashlyticsReporter({
    RecordErrorCallback? recordError,
    SetCustomKeyCallback? setCustomKey,
    SetUserIdentifierCallback? setUserIdentifier,
    LogCallback? log,
    this.isCrashlyticsCollectionEnabled,
    this.beforeSend,
  })  : _recordError = recordError ?? _defaultRecordError,
        _setCustomKey = setCustomKey ?? _defaultSetCustomKey,
        _setUserIdentifier = setUserIdentifier ?? _defaultSetUserIdentifier,
        _log = log ?? _defaultLog;

  final RecordErrorCallback _recordError;
  final SetCustomKeyCallback _setCustomKey;
  final SetUserIdentifierCallback _setUserIdentifier;
  final LogCallback _log;

  /// Optional function to check if Crashlytics collection is enabled.
  final bool Function()? isCrashlyticsCollectionEnabled;

  /// Optional callback to filter or modify errors before sending.
  final ErrorInfo? Function(ErrorInfo info)? beforeSend;

  static Future<void> _defaultRecordError(
    dynamic exception,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('FirebaseCrashlyticsReporter: recordError not configured. '
          'Pass FirebaseCrashlytics.instance.recordError to the constructor.');
    }
  }

  static Future<void> _defaultSetCustomKey(String key, Object value) async {
    if (kDebugMode) {
      debugPrint('FirebaseCrashlyticsReporter: setCustomKey not configured.');
    }
  }

  static Future<void> _defaultSetUserIdentifier(String identifier) async {
    if (kDebugMode) {
      debugPrint(
          'FirebaseCrashlyticsReporter: setUserIdentifier not configured.');
    }
  }

  static Future<void> _defaultLog(String message) async {
    if (kDebugMode) {
      debugPrint('FirebaseCrashlyticsReporter: log not configured.');
    }
  }

  @override
  Future<void> report(ErrorInfo info) async {
    // Check if collection is enabled
    if (isCrashlyticsCollectionEnabled?.call() == false) {
      return;
    }

    // Apply beforeSend filter
    final filteredInfo = beforeSend?.call(info) ?? info;
    if (beforeSend != null && filteredInfo != info && filteredInfo == null) {
      return; // Error was filtered out
    }

    final effectiveInfo = filteredInfo ?? info;

    try {
      // Log context information
      await _log('ErrorBoundary caught error');
      await _log('Type: ${effectiveInfo.type.name}');
      await _log('Severity: ${effectiveInfo.severity.name}');

      if (effectiveInfo.source != null) {
        await _log('Source: ${effectiveInfo.source}');
      }

      // Set custom keys for the error
      await _setCustomKey('error_type', effectiveInfo.type.name);
      await _setCustomKey('error_severity', effectiveInfo.severity.name);
      await _setCustomKey(
        'error_timestamp',
        effectiveInfo.effectiveTimestamp.toIso8601String(),
      );

      if (effectiveInfo.source != null) {
        await _setCustomKey('error_source', effectiveInfo.source!);
      }

      // Set context as custom keys
      for (final entry in effectiveInfo.context.entries) {
        await _setCustomKey('ctx_${entry.key}', entry.value.toString());
      }

      // Determine if this is a fatal error
      final isFatal = effectiveInfo.severity == ErrorSeverity.critical;

      // Record the error
      await _recordError(
        effectiveInfo.error,
        effectiveInfo.stackTrace,
        reason: 'ErrorBoundary: ${effectiveInfo.message}',
        fatal: isFatal,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseCrashlyticsReporter: Failed to report error: $e');
      }
    }
  }

  @override
  void setUserIdentifier(String? userId) {
    if (userId != null) {
      _setUserIdentifier(userId);
    } else {
      _setUserIdentifier('');
    }
  }

  @override
  void setCustomKey(String key, dynamic value) {
    if (value != null) {
      _setCustomKey(key, value);
    }
  }

  /// Logs a message to Crashlytics.
  Future<void> log(String message) => _log(message);
}

/// Signature for Crashlytics' recordError function.
typedef RecordErrorCallback = Future<void> Function(
  dynamic exception,
  StackTrace stack, {
  String? reason,
  bool fatal,
});

/// Signature for Crashlytics' setCustomKey function.
typedef SetCustomKeyCallback = Future<void> Function(String key, Object value);

/// Signature for Crashlytics' setUserIdentifier function.
typedef SetUserIdentifierCallback = Future<void> Function(String identifier);

/// Signature for Crashlytics' log function.
typedef LogCallback = Future<void> Function(String message);
