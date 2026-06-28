/// مقارنة أسماء الخامات: تكرار تام (حروف + مسافات) أو تشابه (مسافات فقط).
String materialNameExactKey(String name) {
  return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// نفس المعنى تقريباً عند إزالة المسافات بالكامل (مثل ST10mm مقابل ST 10mm).
String materialNameLooseKey(String name) {
  return materialNameExactKey(name).replaceAll(' ', '');
}

/// خامة موجودة بنفس الاسم (تجاهل حالة الحروف والمسافات الزائدة).
String? findDuplicateMaterialName(
  String newName,
  List<Map<String, dynamic>> materials, {
  int? excludeId,
}) {
  final key = materialNameExactKey(newName);
  if (key.isEmpty) return null;
  for (final m in materials) {
    final id = m['id'] as int?;
    if (excludeId != null && id == excludeId) continue;
    final existing = (m['name'] as String?) ?? '';
    if (materialNameExactKey(existing) == key) return existing;
  }
  return null;
}

/// خامات مشابهة: نفس الاسم بعد إزالة المسافات، لكن ليست تطابقاً تاماً.
List<String> findSimilarMaterialNames(
  String newName,
  List<Map<String, dynamic>> materials, {
  int? excludeId,
}) {
  final exactKey = materialNameExactKey(newName);
  final looseKey = materialNameLooseKey(newName);
  if (looseKey.isEmpty) return const [];

  final seen = <String>{};
  final similar = <String>[];
  for (final m in materials) {
    final id = m['id'] as int?;
    if (excludeId != null && id == excludeId) continue;
    final existing = (m['name'] as String?) ?? '';
    if (existing.trim().isEmpty) continue;
    if (materialNameExactKey(existing) == exactKey) continue;
    if (materialNameLooseKey(existing) != looseKey) continue;
    if (seen.add(existing)) similar.add(existing);
  }
  similar.sort((a, b) => a.compareTo(b));
  return similar;
}
