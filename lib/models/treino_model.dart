import 'package:focus/models/grupo_muscular.dart';
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
  final GrupoMuscular grupoMuscular;

  /// Exercício do catálogo de origem (foto e músculos). Nulo se criado à mão.
  final String? catalogoId;
  final int series;
  final double cargaKg;
  final int repeticoes;

  const Exercicio({
    this.id,
    required this.nome,
    this.grupoMuscular = GrupoMuscular.outro,
    this.catalogoId,
    required this.series,
    this.cargaKg = 0,
    this.repeticoes = 0,
  });

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      id: (json['id'] as num?)?.toInt(),
      nome: (json['name'] ?? '').toString(),
      grupoMuscular: GrupoMuscular.fromApi(json['muscle_group'] as String?),
      catalogoId: json['catalog_id'] as String?,
      series: (json['sets'] as num? ?? 0).toInt(),
      cargaKg: (json['weight_kg'] as num? ?? 0).toDouble(),
      repeticoes: (json['reps'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': nome,
        'muscle_group': grupoMuscular.valorApi,
        'catalog_id': catalogoId,
        'sets': series,
        'reps': repeticoes,
        'weight_kg': cargaKg,
      };

  String get cargaFormatada => formatarCarga(cargaKg);
}

/// Plano de treino. Cada vez que o usuário toca em "Iniciar", vira uma [SessaoTreino].
class Treino {
  final int? id;
  final String nomeSessao;
  final TipoTreino tipo;
  final DateTime? criadoEm;
  final int seriesTotais;
  final List<Exercicio> exercicios;

  Treino({
    this.id,
    required this.nomeSessao,
    this.tipo = TipoTreino.musculacao,
    this.criadoEm,
    int? seriesTotais,
    required this.exercicios,
  }) : seriesTotais = seriesTotais ?? exercicios.fold(0, (soma, e) => soma + e.series);

  factory Treino.fromJson(Map<String, dynamic> json) {
    final exercicios = (json['exercises'] as List? ?? [])
        .map((e) => Exercicio.fromJson(e as Map<String, dynamic>))
        .toList();
    final criadoEm = json['created_at'] as String?;

    return Treino(
      id: (json['id'] as num?)?.toInt(),
      nomeSessao: (json['name'] ?? 'Treino Sem Nome').toString(),
      tipo: TipoTreino.fromApi(json['type'] as String?),
      criadoEm: criadoEm == null ? null : DateTime.parse(criadoEm).toLocal(),
      seriesTotais: (json['total_sets'] as num?)?.toInt(),
      exercicios: exercicios,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': nomeSessao,
        'type': tipo.valorApi,
        'exercises': exercicios.map((e) => e.toJson()).toList(),
      };

  /// Grupos musculares trabalhados, na ordem em que aparecem, sem repetição.
  List<GrupoMuscular> get gruposMusculares {
    final grupos = <GrupoMuscular>{};
    for (final e in exercicios) {
      if (e.grupoMuscular != GrupoMuscular.outro) grupos.add(e.grupoMuscular);
    }
    return grupos.toList();
  }
}
