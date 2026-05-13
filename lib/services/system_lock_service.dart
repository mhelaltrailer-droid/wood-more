import '../models/user_model.dart';
import 'auth_persistence.dart';
import 'storage_service.dart';

const String maintenanceBypassEmail = 'mouhammedhelal@gmail.com';

bool isMaintenanceBypassEmail(String? email) =>
    (email ?? '').trim().toLowerCase() == maintenanceBypassEmail;

bool shouldForceSignOutForMaintenance(UserModel user, bool locked) =>
    locked && !isMaintenanceBypassEmail(user.email);

/// Returns true when the stored session was cleared for maintenance lock.
Future<bool> enforceMaintenanceSignOutIfNeeded(UserModel user) async {
  if (!shouldForceSignOutForMaintenance(
    user,
    await getStorage().isSystemLocked(),
  )) {
    return false;
  }
  await clearCurrentUser();
  return true;
}
