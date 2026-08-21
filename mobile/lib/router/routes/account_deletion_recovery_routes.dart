// ABOUTME: Full-screen route for interrupted account-deletion recovery.

import 'package:go_router/go_router.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';

List<RouteBase> accountDeletionRecoveryRoutes() => [
  GoRoute(
    path: AccountDeletionRecoveryScreen.path,
    name: AccountDeletionRecoveryScreen.routeName,
    builder: (_, _) => const AccountDeletionRecoveryScreen(),
  ),
];
