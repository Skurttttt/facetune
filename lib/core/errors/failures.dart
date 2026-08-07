abstract class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String? message])
    : super(message ?? 'An unexpected error occurred.');
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
