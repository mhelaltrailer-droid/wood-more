/// مشرف
class SupervisorModel {
  final int id;
  final String name;

  const SupervisorModel({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory SupervisorModel.fromMap(Map<String, dynamic> m) =>
      SupervisorModel(id: m['id'] as int, name: m['name'] as String);
}
