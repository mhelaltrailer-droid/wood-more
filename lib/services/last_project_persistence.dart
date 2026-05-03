import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'auth_persistence.dart';

const String _keyLastAttendanceProjectByUser =
    'wood_last_attendance_project_by_user';

class LastAttendanceProject {
  final int? projectId;
  final String projectName;

  const LastAttendanceProject({
    required this.projectId,
    required this.projectName,
  });
}

Future<void> saveLastAttendanceProjectForUser({
  required int userId,
  required int? projectId,
  required String projectName,
}) async {
  if (projectName.trim().isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastAttendanceProjectByUser);
  Map<String, dynamic> all = {};
  if (raw != null && raw.isNotEmpty) {
    try {
      all = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      all = {};
    }
  }
  all[userId.toString()] = {
    'projectId': projectId,
    'projectName': projectName.trim(),
  };
  await prefs.setString(_keyLastAttendanceProjectByUser, jsonEncode(all));
}

Future<LastAttendanceProject?> getLastAttendanceProjectForUser(
  int userId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastAttendanceProjectByUser);
  if (raw == null || raw.isEmpty) return null;
  try {
    final all = jsonDecode(raw) as Map<String, dynamic>;
    final row = all[userId.toString()];
    if (row is! Map<String, dynamic>) return null;
    final pidRaw = row['projectId'];
    final projectId = pidRaw == null ? null : int.tryParse(pidRaw.toString());
    final projectName = (row['projectName'] ?? '').toString().trim();
    if (projectName.isEmpty) return null;
    return LastAttendanceProject(
      projectId: projectId,
      projectName: projectName,
    );
  } catch (_) {
    return null;
  }
}

Future<void> saveLastLoginProject({
  required int? projectId,
  required String projectName,
}) async {
  if (projectName.trim().isEmpty) return;
  final UserModel? user = await getStoredUser();
  if (user == null) return;
  await saveLastAttendanceProjectForUser(
    userId: user.id,
    projectId: projectId,
    projectName: projectName,
  );
}
