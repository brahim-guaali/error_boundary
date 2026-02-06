import 'package:flutter/foundation.dart';

/// Defines how [ErrorBoundary] should attempt to recover from errors.
@immutable
sealed class RecoveryStrategy {
  const RecoveryStrategy();

  /// No automatic recovery - shows fallback until manual retry.
  const factory RecoveryStrategy.none() = NoRecovery;

  /// Automatically retry rendering the child widget.
  ///
  /// [maxAttempts] - Maximum number of retry attempts (default: 3).
  /// [delay] - Delay between retry attempts (default: 1 second).
  /// [backoff] - Whether to use exponential backoff (default: true).
  const factory RecoveryStrategy.retry({
    int maxAttempts,
    Duration delay,
    bool backoff,
  }) = RetryRecovery;

  /// Reset the widget state and try again.
  ///
  /// This forces a complete rebuild of the child widget tree.
  const factory RecoveryStrategy.reset() = ResetRecovery;

  /// Custom recovery strategy with a callback.
  ///
  /// [onRecover] is called when recovery is attempted.
  /// Return `true` to indicate successful recovery, `false` otherwise.
  const factory RecoveryStrategy.custom({
    required Future<bool> Function() onRecover,
  }) = CustomRecovery;
}

/// No automatic recovery strategy.
final class NoRecovery extends RecoveryStrategy {
  const NoRecovery();

  @override
  String toString() => 'RecoveryStrategy.none()';
}

/// Retry recovery strategy with configurable attempts and delays.
final class RetryRecovery extends RecoveryStrategy {
  const RetryRecovery({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.backoff = true,
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than 0');

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Base delay between retry attempts.
  final Duration delay;

  /// Whether to use exponential backoff for delays.
  final bool backoff;

  /// Calculates the delay for a given attempt number.
  Duration getDelayForAttempt(int attempt) {
    if (!backoff) return delay;
    final multiplier = 1 << (attempt - 1); // 2^(attempt-1)
    return delay * multiplier;
  }

  @override
  String toString() =>
      'RecoveryStrategy.retry(maxAttempts: $maxAttempts, delay: $delay, backoff: $backoff)';
}

/// Reset recovery strategy that rebuilds the entire child tree.
final class ResetRecovery extends RecoveryStrategy {
  const ResetRecovery();

  @override
  String toString() => 'RecoveryStrategy.reset()';
}

/// Custom recovery strategy with user-defined logic.
final class CustomRecovery extends RecoveryStrategy {
  const CustomRecovery({required this.onRecover});

  /// Callback invoked when recovery is attempted.
  ///
  /// Returns `true` if recovery was successful, `false` otherwise.
  final Future<bool> Function() onRecover;

  @override
  String toString() => 'RecoveryStrategy.custom()';
}
