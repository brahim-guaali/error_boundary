import 'package:flutter/foundation.dart';

import '../error_info.dart';
import 'reporter.dart';

/// An [ErrorReporter] that sends errors to Sentry.
///
/// This reporter requires the `sentry_flutter` package to be installed.
///
/// ## Setup
///
/// 1. Add `sentry_flutter` to your `pubspec.yaml`:
///    ```yaml
///    dependencies:
///      sentry_flutter: ^7.0.0
///    ```
///
/// 2. Initialize Sentry in your app:
///    ```dart
///    await SentryFlutter.init(
///      (options) => options.dsn = 'YOUR_DSN',
///      appRunner: () => runApp(MyApp()),
///    );
///    ```
///
/// 3. Use the reporter:
///    ```dart
///    ErrorBoundary(
///      reporters: [SentryReporter()],
///      child: MyWidget(),
///    )
///    ```
///
/// ## Example with Custom Configuration
///
/// ```dart
/// SentryReporter(
///   captureException: Sentry.captureException,
///   configureScope: Sentry.configureScope,
///   beforeSend: (info) {
///     // Filter or modify errors before sending
///     if (info.error is IgnorableError) return null;
///     return info;
///   },
/// )
/// ```
class SentryReporter implements ErrorReporter {
  /// Creates a Sentry reporter.
  ///
  /// [captureException] - Function to capture exceptions (defaults to a no-op).
  /// Pass `Sentry.captureException` when using the sentry_flutter package.
  ///
  /// [configureScope] - Function to configure Sentry scope (defaults to a no-op).
  /// Pass `Sentry.configureScope` when using the sentry_flutter package.
  ///
  /// [beforeSend] - Optional callback to filter or modify errors before sending.
  /// Return `null` to skip sending the error.
  ///
  /// [environment] - Optional environment name (e.g., 'production', 'staging').
  ///
  /// [release] - Optional release/version identifier.
  SentryReporter({
    CaptureExceptionCallback? captureException,
    ConfigureScopeCallback? configureScope,
    this.beforeSend,
    this.environment,
    this.release,
  })  : _captureException = captureException ?? _defaultCaptureException,
        _configureScope = configureScope ?? _defaultConfigureScope;

  final CaptureExceptionCallback _captureException;
  final ConfigureScopeCallback _configureScope;

  /// Optional callback to filter or modify errors before sending.
  final ErrorInfo? Function(ErrorInfo info)? beforeSend;

  /// Optional environment name.
  final String? environment;

  /// Optional release/version identifier.
  final String? release;

  String? _userId;
  final Map<String, dynamic> _customKeys = {};
  final Map<String, String> _tags = {};

  static Future<void> _defaultCaptureException(
    dynamic exception, {
    dynamic stackTrace,
    dynamic hint,
  }) async {
    if (kDebugMode) {
      debugPrint('SentryReporter: captureException not configured. '
          'Pass Sentry.captureException to the constructor.');
    }
  }

  static void _defaultConfigureScope(void Function(dynamic) callback) {
    if (kDebugMode) {
      debugPrint('SentryReporter: configureScope not configured. '
          'Pass Sentry.configureScope to the constructor.');
    }
  }

  @override
  Future<void> report(ErrorInfo info) async {
    // Apply beforeSend filter
    ErrorInfo effectiveInfo = info;
    if (beforeSend != null) {
      final filteredInfo = beforeSend!(info);
      if (filteredInfo == null) {
        return; // Error was filtered out
      }
      effectiveInfo = filteredInfo;
    }

    try {
      // Configure scope with additional context
      _configureScope((scope) {
        // Set level based on severity
        _setScopeLevel(scope, effectiveInfo.severity);

        // Set tags
        _setScopeTag(scope, 'error_type', effectiveInfo.type.name);
        _setScopeTag(scope, 'error_severity', effectiveInfo.severity.name);

        if (effectiveInfo.source != null) {
          _setScopeTag(scope, 'error_source', effectiveInfo.source!);
        }

        if (environment != null) {
          _setScopeTag(scope, 'environment', environment!);
        }

        // Set extra context
        if (effectiveInfo.context.isNotEmpty) {
          _setScopeExtra(scope, 'error_context', effectiveInfo.context);
        }

        // Set custom tags
        for (final entry in _tags.entries) {
          _setScopeTag(scope, entry.key, entry.value);
        }
      });

      // Capture the exception
      await _captureException(
        effectiveInfo.error,
        stackTrace: effectiveInfo.stackTrace,
        hint: _buildHint(effectiveInfo),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SentryReporter: Failed to report error: $e');
      }
    }
  }

  void _setScopeLevel(dynamic scope, ErrorSeverity severity) {
    try {
      final levelName = switch (severity) {
        ErrorSeverity.low => 'info',
        ErrorSeverity.medium => 'warning',
        ErrorSeverity.high => 'error',
        ErrorSeverity.critical => 'fatal',
      };
      // Use reflection-like approach to set level
      (scope as dynamic).level = levelName;
    } catch (_) {
      // Scope might not support level
    }
  }

  void _setScopeTag(dynamic scope, String key, String value) {
    try {
      (scope as dynamic).setTag(key, value);
    } catch (_) {
      // Scope might not support setTag
    }
  }

  void _setScopeExtra(dynamic scope, String key, dynamic value) {
    try {
      (scope as dynamic).setExtra(key, value);
    } catch (_) {
      // Scope might not support setExtra
    }
  }

  Map<String, dynamic> _buildHint(ErrorInfo info) {
    return {
      'error_boundary': true,
      'timestamp': info.effectiveTimestamp.toIso8601String(),
      'type': info.type.name,
      'severity': info.severity.name,
      if (info.source != null) 'source': info.source,
      if (release != null) 'release': release,
      ..._customKeys,
    };
  }

  @override
  void setUserIdentifier(String? userId) {
    _userId = userId;
    _configureScope((scope) {
      try {
        if (userId != null) {
          (scope as dynamic).setUser({'id': userId});
        } else {
          (scope as dynamic).setUser(null);
        }
      } catch (_) {
        // Scope might not support setUser
      }
    });
  }

  @override
  void setCustomKey(String key, dynamic value) {
    if (value == null) {
      _customKeys.remove(key);
      _tags.remove(key);
    } else {
      _customKeys[key] = value;
      if (value is String) {
        _tags[key] = value;
      } else {
        _tags[key] = value.toString();
      }
    }
  }

  /// Adds a tag that will be sent with all error reports.
  void addTag(String key, String value) {
    _tags[key] = value;
  }

  /// Removes a tag.
  void removeTag(String key) {
    _tags.remove(key);
  }
}

/// Signature for Sentry's captureException function.
typedef CaptureExceptionCallback = Future<void> Function(
  dynamic exception, {
  dynamic stackTrace,
  dynamic hint,
});

/// Signature for Sentry's configureScope function.
typedef ConfigureScopeCallback = void Function(
  void Function(dynamic scope) callback,
);
