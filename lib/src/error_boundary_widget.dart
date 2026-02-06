import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'error_info.dart';
import 'recovery_strategy.dart';
import 'reporters/reporter.dart';

/// Signature for building fallback UI when an error occurs.
///
/// [error] - Information about the error that occurred.
/// [retry] - Callback to retry rendering the child widget.
typedef FallbackBuilder = Widget Function(ErrorInfo error, VoidCallback retry);

/// Signature for error callbacks.
typedef ErrorCallback = void Function(Object error, StackTrace stackTrace);

/// Signature for determining if an error should be rethrown to parent boundaries.
typedef ShouldRethrow = bool Function(Object error);

/// A widget that catches errors in its child widget tree and displays a fallback UI.
///
/// Similar to React's Error Boundaries, this widget prevents the entire app from
/// crashing when an error occurs in a part of the widget tree.
///
/// ## Basic Usage
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   fallback: (error, retry) => Center(
///     child: Column(
///       mainAxisSize: MainAxisSize.min,
///       children: [
///         Text('Something went wrong'),
///         ElevatedButton(
///           onPressed: retry,
///           child: Text('Retry'),
///         ),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// ## With Error Reporting
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   reporters: [SentryReporter(), ConsoleReporter()],
///   onError: (error, stack) => print('Error: $error'),
/// )
/// ```
///
/// ## Nested Boundaries
///
/// Error boundaries can be nested. By default, errors are contained within
/// the innermost boundary. Use [shouldRethrow] to bubble errors up.
///
/// ```dart
/// ErrorBoundary(
///   onError: (e, s) => print('Outer caught: $e'),
///   child: ErrorBoundary(
///     shouldRethrow: (e) => e is CriticalError,
///     child: MyWidget(),
///   ),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  /// Creates an error boundary.
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.reporters = const [],
    this.recovery = const RecoveryStrategy.none(),
    this.shouldRethrow,
    this.catchAsync = true,
    this.devMode,
  });

  /// The widget to wrap with error handling.
  final Widget child;

  /// Builder for the fallback UI shown when an error occurs.
  ///
  /// If not provided, a default error widget is shown.
  final FallbackBuilder? fallback;

  /// Callback invoked when an error is caught.
  ///
  /// This is called in addition to any [reporters].
  final ErrorCallback? onError;

  /// List of error reporters to send errors to.
  final List<ErrorReporter> reporters;

  /// Strategy for recovering from errors.
  final RecoveryStrategy recovery;

  /// Determines if an error should be rethrown to parent boundaries.
  ///
  /// If this returns `true`, the error is rethrown after being handled locally.
  final ShouldRethrow? shouldRethrow;

  /// Whether to catch async errors (Futures/Streams) within this boundary.
  ///
  /// When `true`, a [Zone] is created to catch async errors.
  /// Defaults to `true`.
  final bool catchAsync;

  /// Whether to show detailed error information.
  ///
  /// Defaults to [kDebugMode].
  final bool? devMode;

  /// Returns the nearest [ErrorBoundaryState] ancestor.
  static ErrorBoundaryState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ErrorBoundaryState>();
  }

  /// Returns the nearest [ErrorBoundaryState] ancestor, throwing if not found.
  static ErrorBoundaryState of(BuildContext context) {
    final state = maybeOf(context);
    assert(state != null, 'No ErrorBoundary found in context');
    return state!;
  }

  @override
  State<ErrorBoundary> createState() => ErrorBoundaryState();
}

/// State for [ErrorBoundary].
class ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorInfo? _error;
  int _retryCount = 0;
  Key _childKey = UniqueKey();
  bool _isRecovering = false;
  FlutterExceptionHandler? _previousErrorHandler;

  /// The current error, if any.
  ErrorInfo? get error => _error;

  /// Whether the boundary is currently in an error state.
  bool get hasError => _error != null;

  /// Whether dev mode is enabled.
  bool get devMode => widget.devMode ?? kDebugMode;

  @override
  void initState() {
    super.initState();
    _setupErrorHandler();
  }

  @override
  void dispose() {
    _restoreErrorHandler();
    super.dispose();
  }

  void _setupErrorHandler() {
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Check if this error is from our subtree
      if (_isErrorFromOurSubtree(details)) {
        _handleFlutterError(details);
      } else {
        // Pass to previous handler
        _previousErrorHandler?.call(details);
      }
    };
  }

  void _restoreErrorHandler() {
    if (FlutterError.onError == _handleFlutterError) {
      FlutterError.onError = _previousErrorHandler;
    }
  }

  bool _isErrorFromOurSubtree(FlutterErrorDetails details) {
    // Check if the error context mentions our widget or is from build phase
    final context = details.context;
    if (context != null) {
      final contextString = context.toString();
      if (contextString.contains('ErrorBoundary')) {
        return false; // Don't catch our own errors
      }
    }
    // For build errors, we catch them
    return details.library == 'widgets library' ||
        details.library == 'rendering library';
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    _handleError(
      details.exception,
      details.stack ?? StackTrace.current,
      type: ErrorType.build,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildFallback(_error!);
    }

    Widget child = KeyedSubtree(
      key: _childKey,
      child: _ErrorBoundaryScope(
        state: this,
        child: widget.child,
      ),
    );

    if (widget.catchAsync) {
      child = _AsyncErrorCatcher(
        onError: _handleError,
        child: child,
      );
    }

    return child;
  }

  Widget _buildFallback(ErrorInfo error) {
    if (widget.fallback != null) {
      return widget.fallback!(error, retry);
    }

    return _DefaultErrorWidget(
      error: error,
      onRetry: retry,
      devMode: devMode,
    );
  }

  /// Handles an error caught by the boundary.
  void _handleError(Object error, StackTrace stackTrace, {ErrorType? type}) {
    final info = ErrorInfo(
      error: error,
      stackTrace: stackTrace,
      type: type ?? _inferErrorType(error),
      timestamp: DateTime.now(),
    );

    // Report to all reporters
    _reportError(info);

    // Call error callback
    widget.onError?.call(error, stackTrace);

    // Update state to show fallback
    if (mounted) {
      setState(() {
        _error = info;
      });
    }

    // Attempt automatic recovery if configured
    _attemptRecovery();

    // Rethrow if configured
    if (widget.shouldRethrow?.call(error) ?? false) {
      throw error;
    }
  }

  Future<void> _reportError(ErrorInfo info) async {
    for (final reporter in widget.reporters) {
      try {
        await reporter.report(info);
      } catch (e) {
        // Don't let reporter errors cause issues
        if (kDebugMode) {
          debugPrint('ErrorBoundary: Reporter failed: $e');
        }
      }
    }
  }

  ErrorType _inferErrorType(Object error) {
    if (error is FlutterError) {
      final message = error.message;
      if (message.contains('build')) return ErrorType.build;
      if (message.contains('render')) return ErrorType.rendering;
      if (message.contains('state')) return ErrorType.state;
    }
    if (error is AsyncError) return ErrorType.async;
    return ErrorType.runtime;
  }

  Future<void> _attemptRecovery() async {
    if (_isRecovering) return;

    switch (widget.recovery) {
      case NoRecovery():
        // No automatic recovery
        break;

      case RetryRecovery(:final maxAttempts, :final delay, :final backoff):
        if (_retryCount < maxAttempts) {
          _isRecovering = true;
          final waitTime = backoff ? delay * (1 << _retryCount) : delay;
          await Future.delayed(waitTime);
          _isRecovering = false;
          retry();
        }

      case ResetRecovery():
        _isRecovering = true;
        await Future.delayed(const Duration(milliseconds: 100));
        _isRecovering = false;
        reset();

      case CustomRecovery(:final onRecover):
        _isRecovering = true;
        try {
          final success = await onRecover();
          if (success && mounted) {
            retry();
          }
        } finally {
          _isRecovering = false;
        }
    }
  }

  /// Retries rendering the child widget.
  void retry() {
    if (mounted) {
      setState(() {
        _error = null;
        _retryCount++;
      });
    }
  }

  /// Resets the boundary state completely, forcing a rebuild of the child.
  void reset() {
    if (mounted) {
      setState(() {
        _error = null;
        _retryCount = 0;
        _childKey = UniqueKey();
      });
    }
  }

  /// Manually triggers an error state.
  ///
  /// Useful for testing or forcing error UI display.
  void triggerError(Object error, [StackTrace? stackTrace]) {
    _handleError(error, stackTrace ?? StackTrace.current);
  }
}

/// InheritedWidget to provide ErrorBoundaryState to descendants.
class _ErrorBoundaryScope extends InheritedWidget {
  const _ErrorBoundaryScope({
    required this.state,
    required super.child,
  });

  final ErrorBoundaryState state;

  @override
  bool updateShouldNotify(_ErrorBoundaryScope oldWidget) {
    return state != oldWidget.state;
  }
}

/// Internal widget that catches async errors using a Zone.
class _AsyncErrorCatcher extends StatefulWidget {
  const _AsyncErrorCatcher({
    required this.onError,
    required this.child,
  });

  final void Function(Object, StackTrace, {ErrorType? type}) onError;
  final Widget child;

  @override
  State<_AsyncErrorCatcher> createState() => _AsyncErrorCatcherState();
}

class _AsyncErrorCatcherState extends State<_AsyncErrorCatcher> {
  late final Zone _zone;

  @override
  void initState() {
    super.initState();
    _zone = Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
          widget.onError(error, stackTrace, type: ErrorType.async);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _zone.run(() => widget.child);
  }
}

/// Default error widget shown when no fallback is provided.
class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({
    required this.error,
    required this.onRetry,
    required this.devMode,
  });

  final ErrorInfo error;
  final VoidCallback onRetry;
  final bool devMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (devMode) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension methods for easily wrapping widgets with error boundaries.
extension ErrorBoundaryExtension on Widget {
  /// Wraps this widget with an [ErrorBoundary].
  ///
  /// ```dart
  /// MyWidget().withErrorBoundary(
  ///   fallback: (error, retry) => Text('Error!'),
  /// )
  /// ```
  Widget withErrorBoundary({
    Key? key,
    FallbackBuilder? fallback,
    ErrorCallback? onError,
    List<ErrorReporter> reporters = const [],
    RecoveryStrategy recovery = const RecoveryStrategy.none(),
    ShouldRethrow? shouldRethrow,
    bool catchAsync = true,
    bool? devMode,
  }) {
    return ErrorBoundary(
      key: key,
      fallback: fallback,
      onError: onError,
      reporters: reporters,
      recovery: recovery,
      shouldRethrow: shouldRethrow,
      catchAsync: catchAsync,
      devMode: devMode,
      child: this,
    );
  }
}
