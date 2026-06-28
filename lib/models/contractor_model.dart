/// مقاول
class ContractorModel {
  final int id;
  final String name;

  const ContractorModel({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory ContractorModel.fromMap(Map<String, dynamic> m) {
    int parseId(dynamic v) => v is int ? v : int.parse(v.toString());
    return ContractorModel(
      id: parseId(m['id']),
      name: (m['name'] ?? '').toString(),
    );
  }
}
