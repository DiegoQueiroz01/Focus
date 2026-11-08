import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/treino_model.dart';

/// Uma execução de treino, do toque em "Iniciar" até "Finalizar".
class SessaoTreino {
  final int id;
  final int? treinoId;
  final String nomeTreino;
  final TipoTreino tipo;
  final DateTime iniciadaEm;
  final DateTime? finalizadaEm;
  final int duracaoSegundos;
  final double volumeTotalKg;
  final int seriesTotais;
  final GrupoMuscular? ultimoGrupoMuscular;

  const SessaoTreino({
    required this.id,
    this.treinoId,
    required this.nomeTreino,
    this.tipo = TipoTreino.musculacao,
    required this.iniciadaEm,
    this.finalizadaEm,
    this.duracaoSegundos = 0,
    this.volumeTotalKg = 0,
    this.seriesTotais = 0,
    this.ultimoGrupoMuscular,
  });

  bool get emAndamento => finalizadaEm == null;

  factory SessaoTreino.fromJson(Map<String, dynamic> json) {
    final finalizada = json['finished_at'] as String?;
    return SessaoTreino(
      id: (json['id'] as num).toInt(),
      treinoId: (json['workout_id'] as num?)?.toInt(),
      nomeTreino: (json['workout_name'] ?? '').toString(),
      tipo: TipoTreino.fromApi(json['workout_type'] as String?),
      iniciadaEm: DateTime.parse(json['started_at'] as String).toLocal(),
      finalizadaEm: finalizada == null ? null : DateTime.parse(finalizada).toLocal(),
      duracaoSegundos: (json['duration_seconds'] as num? ?? 0).toInt(),
      volumeTotalKg: (json['total_volume_kg'] as num? ?? 0).toDouble(),
      seriesTotais: (json['total_sets'] as num? ?? 0).toInt(),
      ultimoGrupoMuscular: GrupoMuscular.fromApiOuNulo(json['last_muscle_group'] as String?),
    );
  }
}
