import 'package:flutter/material.dart';
import '../utils/roles.dart';
import 'admin/admin_home_screen.dart';
import 'warehouse/warehouse_home_screen.dart';
import 'user/user_home_screen.dart';
import 'supervisor/supervisor_home_screen.dart';
import 'finance/finance_home_screen.dart';

/// Returns the home screen widget for a given role.
Widget homeScreenForRole(String? role) {
  final r = normalizeRole(role);
  if (r == 'admin' || r == 'manager') {
    return const AdminHomeScreen();
  }
  if (isWarehouseLike(r)) {
    return const WarehouseHomeScreen();
  }
  if (r == 'supervisor') {
    return const SupervisorHomeScreen();
  }
  if (r == 'finance') {
    return const FinanceHomeScreen();
  }
  return const UserHomeScreen();
}
