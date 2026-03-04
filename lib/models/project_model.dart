/// نموذج المشروع
class ProjectModel {
  final int id;
  final String name;

  const ProjectModel({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}
