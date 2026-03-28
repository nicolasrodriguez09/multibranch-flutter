import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';

void main() {
  test('user role parser tolerates casing and whitespace', () {
    expect(UserRole.fromValue('admin'), UserRole.admin);
    expect(UserRole.fromValue(' Admin '), UserRole.admin);
    expect(UserRole.fromValue('SUPERVISOR'), UserRole.supervisor);
  });
}
