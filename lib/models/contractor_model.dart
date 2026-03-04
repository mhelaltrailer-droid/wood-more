/// مقاول
class ContractorModel {
  final int id;
  final String name;

  const ContractorModel({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory ContractorModel.fromMap(Map<String, dynamic> m) =>
      ContractorModel(id: m['id'] as int, name: m['name'] as String);
}
