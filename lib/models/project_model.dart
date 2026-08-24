/// نموذج المشروع
class ProjectModel {
  final int id;
  final String name;
  /// المقاول الرئيسي للمشروع (Main Contractor) — يُستخدم في أذن الصرف/التسليم
  final String mainContractor;

  const ProjectModel({
    required this.id,
    required this.name,
    this.mainContractor = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'main_contractor': mainContractor,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}') ?? 0,
      name: (map['name'] ?? '') as String,
      mainContractor: (map['main_contractor'] ??
              map['mainContractor'] ??
              '')
          .toString(),
    );
  }
}
