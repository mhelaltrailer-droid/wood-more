import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// مسودة نصية محلية لشاشة «إنشاء خطة عمل الغد» فقط.
/// المفتاح: مستخدم + مشروع. المحتوى: حقلان نصّيان فقط (بدون مرفقات/بنود).
class TomorrowWorkPlanTextDraft {
  final String executedTodaySummary;
  final String tomorrowPlanDetails;

  const TomorrowWorkPlanTextDraft({
    this.executedTodaySummary = '',
    this.tomorrowPlanDetails = '',
  });

  bool get isEmpty =>
      executedTodaySummary.trim().isEmpty && tomorrowPlanDetails.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'executedTodaySummary': executedTodaySummary,
        'tomorrowPlanDetails': tomorrowPlanDetails,
      };

  factory TomorrowWorkPlanTextDraft.fromJson(Map<String, dynamic> m) {
    return TomorrowWorkPlanTextDraft(
      executedTodaySummary: (m['executedTodaySummary'] ?? '').toString(),
      tomorrowPlanDetails: (m['tomorrowPlanDetails'] ?? '').toString(),
    );
  }
}

const String _kStoreKey = 'wood_tomorrow_work_plan_text_drafts_v1';

String _entryKey(int userId, int projectId) => '$userId:$projectId';

Future<Map<String, dynamic>> _readAll(SharedPreferences prefs) async {
  final raw = prefs.getString(_kStoreKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {}
  return {};
}

Future<void> _writeAll(
  SharedPreferences prefs,
  Map<String, dynamic> all,
) async {
  await prefs.setString(_kStoreKey, jsonEncode(all));
}

Future<TomorrowWorkPlanTextDraft?> getTomorrowWorkPlanTextDraft({
  required int userId,
  required int projectId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final all = await _readAll(prefs);
  final row = all[_entryKey(userId, projectId)];
  if (row is! Map) return null;
  try {
    final draft = TomorrowWorkPlanTextDraft.fromJson(
      Map<String, dynamic>.from(row),
    );
    return draft.isEmpty ? null : draft;
  } catch (_) {
    return null;
  }
}

Future<void> saveTomorrowWorkPlanTextDraft({
  required int userId,
  required int projectId,
  required String executedTodaySummary,
  required String tomorrowPlanDetails,
}) async {
  final draft = TomorrowWorkPlanTextDraft(
    executedTodaySummary: executedTodaySummary,
    tomorrowPlanDetails: tomorrowPlanDetails,
  );
  final prefs = await SharedPreferences.getInstance();
  final all = await _readAll(prefs);
  final key = _entryKey(userId, projectId);
  if (draft.isEmpty) {
    all.remove(key);
  } else {
    all[key] = draft.toJson();
  }
  await _writeAll(prefs, all);
}

Future<void> clearTomorrowWorkPlanTextDraft({
  required int userId,
  required int projectId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final all = await _readAll(prefs);
  all.remove(_entryKey(userId, projectId));
  await _writeAll(prefs, all);
}
