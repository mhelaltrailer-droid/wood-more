/// عقدة في هيكل مواقع المشروع: إما حاوية (folder) أو موقع عمل (work_site)
class ProjectLocationModel {
  final int id;
  final int projectId;
  final int? parentId;
  final String name;
  final String type; // 'folder' | 'work_site'
  final int displayOrder;

  const ProjectLocationModel({
    required this.id,
    required this.projectId,
    this.parentId,
    required this.name,
    required this.type,
    this.displayOrder = 0,
  });

  bool get isFolder => type == 'folder';
  bool get isWorkSite => type == 'work_site';

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'parent_id': parentId,
        'name': name,
        'type': type,
        'display_order': displayOrder,
      };

  factory ProjectLocationModel.fromMap(Map<String, dynamic> m) {
    return ProjectLocationModel(
      id: m['id'] is int ? m['id'] as int : int.parse(m['id'].toString()),
      projectId: m['project_id'] is int ? m['project_id'] as int : int.parse(m['project_id'].toString()),
      parentId: m['parent_id'] == null ? null : (m['parent_id'] is int ? m['parent_id'] as int : int.parse(m['parent_id'].toString())),
      name: m['name'] as String,
      type: m['type'] as String? ?? 'folder',
      displayOrder: m['display_order'] is int ? m['display_order'] as int : int.tryParse(m['display_order']?.toString() ?? '0') ?? 0,
    );
  }
}
