/// 🎯 Result Pattern for Enterprise-Level Error Handling
///
/// This provides a type-safe way to handle success and failure cases
/// across all async operations (AI, Database, Network, etc.)
library;

/// Base class for all operation results
abstract class Result<T> {
  const Result();

  /// Check if the result is a success
  bool get isSuccess => this is Success<T>;

  /// Check if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Get the value if success, or null if failure
  T? get valueOrNull => isSuccess ? (this as Success<T>).value : null;

  /// Get the error message if failure, or null if success
  String? get errorOrNull => isFailure ? (this as Failure<T>).message : null;
}

/// Represents a successful operation
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed operation
class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  final FailureType type;

  const Failure(
    this.message, {
    this.exception,
    this.type = FailureType.unknown,
  });

  @override
  String toString() => 'Failure($type: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          type == other.type;

  @override
  int get hashCode => message.hashCode ^ type.hashCode;
}

/// Types of failures for better error categorization
enum FailureType {
  network, // Network connectivity issues
  ai, // AI service errors (API, rate limits, etc.)
  database, // Local or remote database errors
  permission, // File/media access permissions
  validation, // Input validation errors
  timeout, // Operation timeout
  unknown, // Unclassified errors
}

/// Specialized failure types for common scenarios

class NetworkFailure<T> extends Failure<T> {
  const NetworkFailure(super.message, {super.exception})
      : super(type: FailureType.network);
}

class AiFailure<T> extends Failure<T> {
  const AiFailure(super.message, {super.exception})
      : super(type: FailureType.ai);
}

class DatabaseFailure<T> extends Failure<T> {
  const DatabaseFailure(super.message, {super.exception})
      : super(type: FailureType.database);
}

class PermissionFailure<T> extends Failure<T> {
  const PermissionFailure(super.message, {super.exception})
      : super(type: FailureType.permission);
}

class ValidationFailure<T> extends Failure<T> {
  const ValidationFailure(super.message, {super.exception})
      : super(type: FailureType.validation);
}

class TimeoutFailure<T> extends Failure<T> {
  const TimeoutFailure(super.message, {super.exception})
      : super(type: FailureType.timeout);
}

/// Extension methods for convenient Result handling
extension ResultExt<T> on Result<T> {
  /// Pattern matching for Result
  ///
  /// Example:
  /// ```dart
  /// result.when(
  ///   success: (value) => print('Got: $value'),
  ///   failure: (message, exception) => print('Error: $message'),
  /// );
  /// ```
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Exception? exception, FailureType type)
        failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).value);
    } else if (this is Failure<T>) {
      final f = this as Failure<T>;
      return failure(f.message, f.exception, f.type);
    }
    throw StateError('Unknown Result type');
  }

  /// Map the success value to a new type
  ///
  /// Example:
  /// ```dart
  /// Result<int> numberResult = Success(42);
  /// Result<String> stringResult = numberResult.map((n) => n.toString());
  /// ```
  Result<R> map<R>(R Function(T value) transform) {
    if (this is Success<T>) {
      try {
        return Success(transform((this as Success<T>).value));
      } catch (e) {
        return Failure('Transform failed: ${e.toString()}',
            exception: e as Exception?);
      }
    } else {
      final f = this as Failure<T>;
      return Failure<R>(f.message, exception: f.exception, type: f.type);
    }
  }

  /// Chain async operations
  ///
  /// Example:
  /// ```dart
  /// final result = await getUserId()
  ///   .flatMap((id) => fetchUserData(id))
  ///   .flatMap((data) => processData(data));
  /// ```
  Future<Result<R>> flatMap<R>(
      Future<Result<R>> Function(T value) transform) async {
    if (this is Success<T>) {
      try {
        return await transform((this as Success<T>).value);
      } catch (e) {
        return Failure('FlatMap failed: ${e.toString()}',
            exception: e as Exception?);
      }
    } else {
      final f = this as Failure<T>;
      return Failure<R>(f.message, exception: f.exception, type: f.type);
    }
  }

  /// Get value or provide a default
  T getOrElse(T defaultValue) {
    return isSuccess ? (this as Success<T>).value : defaultValue;
  }

  /// Get value or compute a default
  T getOrElseCompute(T Function() defaultValue) {
    return isSuccess ? (this as Success<T>).value : defaultValue();
  }

  /// Execute a side effect only on success
  Result<T> onSuccess(void Function(T value) action) {
    if (this is Success<T>) {
      action((this as Success<T>).value);
    }
    return this;
  }

  /// Execute a side effect only on failure
  Result<T> onFailure(
      void Function(String message, Exception? exception, FailureType type)
          action) {
    if (this is Failure<T>) {
      final f = this as Failure<T>;
      action(f.message, f.exception, f.type);
    }
    return this;
  }
}

/// Helper function to wrap sync operations in Result
Result<T> runCatching<T>(T Function() operation) {
  try {
    return Success(operation());
  } catch (e) {
    return Failure(
      e.toString(),
      exception: e is Exception ? e : Exception(e.toString()),
    );
  }
}

/// Helper function to wrap async operations in Result
Future<Result<T>> runCatchingAsync<T>(Future<T> Function() operation) async {
  try {
    final value = await operation();
    return Success(value);
  } catch (e) {
    return Failure(
      e.toString(),
      exception: e is Exception ? e : Exception(e.toString()),
    );
  }
}
