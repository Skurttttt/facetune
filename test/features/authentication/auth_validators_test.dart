import 'package:facetune/features/authentication/domain/services/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators', () {
    test('validates email shape', () {
      expect(AuthValidators.email('mia@example.com'), isNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });

    test('requires a password with length, letters, and numbers', () {
      expect(AuthValidators.password('beauty123'), isNull);
      expect(AuthValidators.password('short1'), isNotNull);
      expect(AuthValidators.password('allletters'), isNotNull);
    });

    test('requires matching confirmation', () {
      expect(
        AuthValidators.confirmedPassword('beauty123', 'beauty123'),
        isNull,
      );
      expect(
        AuthValidators.confirmedPassword('beauty124', 'beauty123'),
        isNotNull,
      );
    });
  });
}
