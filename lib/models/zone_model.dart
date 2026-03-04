/// منطقة/زون ضمن مشروع
class ZoneModel {
  final int id;
  final int projectId;
  final String name;

  const ZoneModel({required this.id, required this.projectId, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'project_id': projectId, 'name': name};

  factory ZoneModel.fromMap(Map<String, dynamic> m) => ZoneModel(
        id: m['id'] as int,
        projectId: m['project_id'] as int,
        name: m['name'] as String,
      );
}
