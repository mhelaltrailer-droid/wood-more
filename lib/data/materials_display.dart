/// خامات تُعرض دائماً في أعلى قوائم الخامات.
const List<String> priorityMaterialNames = [
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65',
];

int _materialDisplayOrderKey(String name) {
  final idx = priorityMaterialNames.indexOf(name);
  if (idx >= 0) return idx;
  return priorityMaterialNames.length;
}

List<String> sortMaterialsForDisplay(Iterable<String> names) {
  final list = names
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  list.sort((a, b) {
    final order = _materialDisplayOrderKey(a).compareTo(_materialDisplayOrderKey(b));
    if (order != 0) return order;
    return a.compareTo(b);
  });
  return list;
}

List<Map<String, dynamic>> sortMaterialRowsForDisplay(
  List<Map<String, dynamic>> rows,
) {
  final out = List<Map<String, dynamic>>.from(rows);
  out.sort((a, b) {
    final nameA = (a['name'] as String?) ?? '';
    final nameB = (b['name'] as String?) ?? '';
    final order = _materialDisplayOrderKey(nameA).compareTo(_materialDisplayOrderKey(nameB));
    if (order != 0) return order;
    return nameA.compareTo(nameB);
  });
  return out;
}
