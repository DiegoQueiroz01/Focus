import 'package:focus/utils/formatadores.dart';

enum TipoTreino {
  musculacao('strength', 'Musculação'),
  cardio('cardio', 'Cardio'),
  outro('other', 'Outro');

  final String valorApi;
  final String rotulo;

  const TipoTreino(this.valorApi, this.rotulo);

  static TipoTreino fromApi(String? valor) {
    return TipoTreino.values.firstWhere((t) => t.valorApi == valor, orElse: () => TipoTreino.outro);
  }
}

class Exercicio {
  final int? id;
  final String nome;
  final int series;
  final double cargaKg;
  final int repeticoes;

  const Exercicio({
    this.id,
    required this.nome,
    required this.series,
    this.cargaKg = 0,
    this.repeticoes = 0,
  });

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      id: (json['id'] as num?)?.toInt(),
      nome: (json['name'] ?? '').toString(),
      series: (json['sets'] as num? ?? 0).toInt(),
      cargaKg: (json['weight_kg'] as num? ?? 0).toDouble(),
      repeticoes: (json['reps'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': nome,
        'sets': series,
        'reps': repeticoes,
        'weight_kg': cargaKg,
      };

  String get cargaFormatada => formatarCarga(cargaKg);
}

class Treino {
  final int? id;
  final String nomeSessao;
  final TipoTreino tipo;
  final DateTime data;
  final int tempoTotalMinutos;
  final int seriesTotais;
  final List<Exercicio> exercicios;

  Treino({
    this.id,
    required this.nomeSessao,
    this.tipo = TipoTreino.musculacao,
    DateTime? data,
    this.tempoTotalMinutos = 0,
    int? seriesTotais,
    required this.exercicios,
  })  : data = data ?? DateTime.now(),
        seriesTotais = seriesTotais ?? exercicios.fold(0, (soma, e) => soma + e.series);

  factory Treino.fromJson(Map<String, dynamic> json) {
    final exercicios = (json['exercises'] as List? ?? [])
        .map((e) => Exercicio.fromJson(e as Map<String, dynamic>))
        .toList();

    return Treino(
      id: (json['id'] as num?)?.toInt(),
      nomeSessao: (json['name'] ?? 'Treino Sem Nome').toString(),
      tipo: TipoTreino.fromApi(json['type'] as String?),
      data: DateTime.parse(json['performed_at'] as String).toLocal(),
      tempoTotalMinutos: (json['duration_minutes'] as num? ?? 0).toInt(),
      seriesTotais: (json['total_sets'] as num?)?.toInt(),
      exercicios: exercicios,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': nomeSessao,
        'type': tipo.valorApi,
        'performed_at': data.toUtc().toIso8601String(),
        'duration_minutes': tempoTotalMinutos,
        'exercises': exercicios.map((e) => e.toJson()).toList(),
      };

  String get dataFormatada {
    String doisDigitos(int n) => n.toString().padLeft(2, '0');
    return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year} '
        '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
  }
}
