/// مرحلة العمل: تركيب اكسسوارات، تقطيع WPC، تركيب WPC، معالجة، دهان
class WorkPhaseModel {
  final int id;
  final String name;

  const WorkPhaseModel({required this.id, required this.name});

  factory WorkPhaseModel.fromMap(Map<String, dynamic> m) => WorkPhaseModel(
        id: m['id'] is int ? m['id'] as int : int.parse(m['id'].toString()),
        name: m['name'] as String,
      );
}
