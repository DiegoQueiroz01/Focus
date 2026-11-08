import 'package:flutter/material.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/treino_model.dart';

/// Nome em português de cada músculo do catálogo (mesmos nomes usados no desenho do corpo).
const rotulosMusculos = {
  'abdominals': 'Abdômen',
  'abductors': 'Abdutores',
  'adductors': 'Adutores',
  'biceps': 'Bíceps',
  'calves': 'Panturrilha',
  'chest': 'Peito',
  'forearms': 'Antebraço',
  'glutes': 'Glúteos',
  'hamstrings': 'Posterior de coxa',
  'lats': 'Dorsais',
  'lower back': 'Lombar',
  'middle back': 'Meio das costas',
  'neck': 'Pescoço',
  'quadriceps': 'Quadríceps',
  'shoulders': 'Ombros',
  'traps': 'Trapézio',
  'triceps': 'Tríceps',
};

String rotuloMusculo(String musculo) => rotulosMusculos[musculo] ?? musculo;

const _rotulosNivel = {'beginner': 'Iniciante', 'intermediate': 'Intermediário', 'expert': 'Avançado'};

/// Ícone usado nas atividades que não têm foto (natação, futebol, yoga...).
IconData iconeDoCatalogo(String? chave) => switch (chave) {
      'run' => Icons.directions_run_rounded,
      'walk' => Icons.directions_walk_rounded,
      'pool' => Icons.pool_rounded,
      'bike' => Icons.directions_bike_rounded,
      'bolt' => Icons.bolt_rounded,
      'jump' => Icons.sports_gymnastics_rounded,
      'stairs' => Icons.stairs_rounded,
      'dance' => Icons.music_note_rounded,
      'boxing' => Icons.sports_mma_rounded,
      'kayak' => Icons.kayaking_rounded,
      'skate' => Icons.skateboarding_rounded,
      'soccer' => Icons.sports_soccer_rounded,
      'basketball' => Icons.sports_basketball_rounded,
      'volleyball' => Icons.sports_volleyball_rounded,
      'tennis' => Icons.sports_tennis_rounded,
      'handball' => Icons.sports_handball_rounded,
      'surf' => Icons.surfing_rounded,
      'climb' => Icons.terrain_rounded,
      'yoga' => Icons.self_improvement_rounded,
      'pilates' => Icons.accessibility_new_rounded,
      'gymnastics' => Icons.sports_gymnastics_rounded,
      'martial_arts' => Icons.sports_martial_arts_rounded,
      _ => Icons.fitness_center_rounded,
    };

class CatalogoExercicio {
  final String id;
  final String nome;
  final String? nomeIngles;
  final TipoTreino tipo;
  final GrupoMuscular grupoMuscular;
  final List<String> musculosPrincipais;
  final List<String> musculosSecundarios;
  final String? equipamento;
  final String? nivel;
  final String? imagemUrl;
  final String? icone;

  // Só vêm no detalhe.
  final List<String> imagensUrl;
  final String? descricao;
  final List<String> instrucoes;

  const CatalogoExercicio({
    required this.id,
    required this.nome,
    this.nomeIngles,
    required this.tipo,
    required this.grupoMuscular,
    this.musculosPrincipais = const [],
    this.musculosSecundarios = const [],
    this.equipamento,
    this.nivel,
    this.imagemUrl,
    this.icone,
    this.imagensUrl = const [],
    this.descricao,
    this.instrucoes = const [],
  });

  factory CatalogoExercicio.fromJson(Map<String, dynamic> json) {
    List<String> lista(String chave) => (json[chave] as List? ?? const []).cast<String>();
    return CatalogoExercicio(
      id: json['id'] as String,
      nome: json['name'] as String,
      nomeIngles: json['name_en'] as String?,
      tipo: TipoTreino.fromApi(json['type'] as String?),
      grupoMuscular: GrupoMuscular.fromApi(json['muscle_group'] as String?),
      musculosPrincipais: lista('primary_muscles'),
      musculosSecundarios: lista('secondary_muscles'),
      equipamento: json['equipment'] as String?,
      nivel: json['level'] as String?,
      imagemUrl: json['image_url'] as String?,
      icone: json['icon'] as String?,
      imagensUrl: lista('image_urls'),
      descricao: json['description'] as String?,
      instrucoes: lista('instructions'),
    );
  }

  String? get nivelRotulo => _rotulosNivel[nivel];

  /// "Peito, Tríceps" — músculos principais em português.
  String get resumoMusculos => musculosPrincipais.map(rotuloMusculo).join(', ');
}
