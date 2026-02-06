import 'package:flutter/foundation.dart';

/// Severity level of an error.
enum ErrorSeverity {
  /// Low severity - minor issues that don't affect core functionality.
  low,

  /// Medium severity - issues that affect some functionality.
  medium,

  /// High severity - issues that significantly affect the user experience.
  high,

  /// Critical severity - issues that prevent the app from functioning.
  critical,
}

/// Type of error that occurred.
enum ErrorType {
  /// Error during widget build phase.
  build,

  /// Runtime error during execution.
  runtime,

  /// Error during rendering.
  rendering,

  /// Error in state management.
  state,

  /// Error from external service (API, database, etc.).
  external,

  /// Error in async operation (Future, Stream).
  async,

  /// Unknown error type.
  unknown,
}

/// Contains detailed information about an error caught by [ErrorBoundary].
@immutable
class ErrorInfo {
  /// Creates an [ErrorInfo] instance.
  const ErrorInfo({
    required this.error,
    required this.stackTrace,
    this.severity = ErrorSeverity.medium,
    this.type = ErrorType.unknown,
    this.source,
    DateTime? timestamp,
    this.context = const {},
  }) : timestamp = timestamp ?? null;

  /// The actual error object.
  final Object error;

  /// The stack trace when the error occurred.
  final StackTrace stackTrace;

  /// The severity level of the error.
  final ErrorSeverity severity;

  /// The type of error.
  final ErrorType type;

  /// Optional identifier for the source of the error.
  final String? source;

  /// When the error occurred.
  final DateTime? timestamp;

  /// Additional contextual data about the error.
  final Map<String, dynamic> context;

  /// Returns the timestamp, using current time if not set.
  DateTime get effectiveTimestamp => timestamp ?? DateTime.now();

  /// Creates a copy of this [ErrorInfo] with the given fields replaced.
  ErrorInfo copyWith({
    Object? error,
    StackTrace? stackTrace,
    ErrorSeverity? severity,
    ErrorType? type,
    String? source,
    DateTime? timestamp,
    Map<String, dynamic>? context,
  }) {
    return ErrorInfo(
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      severity: severity ?? this.severity,
      type: type ?? this.type,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      context: context ?? this.context,
    );
  }

  /// Returns a human-readable error message.
  String get message => error.toString();

  @override
  String toString() {
    return 'ErrorInfo('
        'error: $error, '
        'type: $type, '
        'severity: $severity, '
        'source: $source, '
        'timestamp: $effectiveTimestamp'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorInfo &&
        other.error == error &&
        other.stackTrace == stackTrace &&
        other.severity == severity &&
        other.type == type &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(error, stackTrace, severity, type, source);
}
