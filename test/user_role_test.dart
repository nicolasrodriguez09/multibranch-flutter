import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/domain/role_permissions.dart';

void main() {
  test('user role parser tolerates casing and whitespace', () {
    expect(UserRole.fromValue('admin'), UserRole.admin);
    expect(UserRole.fromValue(' Admin '), UserRole.admin);
    expect(UserRole.fromValue('SUPERVISOR'), UserRole.supervisor);
  });

  test(
    'permission matrix matches seller, supervisor and admin capabilities',
    () {
      expect(UserRole.seller.can(AppPermission.viewNotifications), isTrue);
      expect(UserRole.seller.can(AppPermission.viewOwnInventory), isTrue);
      expect(UserRole.seller.can(AppPermission.approveTransfer), isFalse);
      expect(UserRole.seller.can(AppPermission.approveReservation), isFalse);
      expect(
        UserRole.seller.can(AppPermission.viewOperationalMetrics),
        isFalse,
      );
      expect(UserRole.supervisor.can(AppPermission.approveTransfer), isTrue);
      expect(UserRole.supervisor.can(AppPermission.approveReservation), isTrue);
      expect(UserRole.supervisor.can(AppPermission.viewNotifications), isTrue);
      expect(
        UserRole.supervisor.can(AppPermission.viewOperationalMetrics),
        isTrue,
      );
      expect(UserRole.supervisor.can(AppPermission.manageEmployees), isFalse);
      expect(UserRole.admin.can(AppPermission.manageEmployees), isTrue);
      expect(UserRole.admin.can(AppPermission.viewNotifications), isTrue);
      expect(UserRole.admin.can(AppPermission.seedMasterData), isTrue);
    },
  );
}
