import 'package:flutter/material.dart';

/// Data no formato da API (AAAA-MM-DD), sempre o dia local do aparelho.
String dataParaApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


DateTime _lerData(String valor) {
  final partes = valor.split('-').map(int.parse).toList();
  return DateTime(partes[0], partes[1], partes[2]);
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

enum Sexo {
  masculino('male', 'Masculino', Icons.male_rounded),
  feminino('female', 'Feminino', Icons.female_rounded);

  final String valorApi;
  final String rotulo;
  final IconData icone;
  const Sexo(this.valorApi, this.rotulo, this.icone);

  static Sexo? deApi(String? v) => values.where((s) => s.valorApi == v).firstOrNull;
}

enum NivelAtividade {
  sedentario('sedentary', 'Sedentário', 'Pouco ou nenhum exercício, trabalho sentado', Icons.weekend_rounded),
  leve('light', 'Levemente ativo', 'Exercício leve 1 a 3 vezes por semana', Icons.directions_walk_rounded),
  moderado('moderate', 'Moderadamente ativo', 'Exercício moderado 3 a 5 vezes por semana', Icons.directions_run_rounded),
  ativo('active', 'Muito ativo', 'Exercício intenso 6 a 7 vezes por semana', Icons.fitness_center_rounded),
  atleta('very_active', 'Extremamente ativo', 'Treino pesado diário ou trabalho físico', Icons.local_fire_department_rounded);

  final String valorApi;
  final String rotulo;
  final String descricao;
  final IconData icone;
  const NivelAtividade(this.valorApi, this.rotulo, this.descricao, this.icone);

  static NivelAtividade? deApi(String? v) => values.where((n) => n.valorApi == v).firstOrNull;
}

enum Objetivo {
  emagrecer('lose', 'Emagrecer', 'Perder gordura com déficit calórico', Icons.trending_down_rounded),
  manter('maintain', 'Manter o peso', 'Comer o mesmo que gasta', Icons.trending_flat_rounded),
  ganhar('gain', 'Ganhar massa', 'Superávit leve para ganhar músculo', Icons.trending_up_rounded);

  final String valorApi;
  final String rotulo;
  final String descricao;
  final IconData icone;
  const Objetivo(this.valorApi, this.rotulo, this.descricao, this.icone);

  static Objetivo? deApi(String? v) => values.where((o) => o.valorApi == v).firstOrNull;
}

enum Ritmo {
  lento('slow', 'Lento'),
  moderado('moderate', 'Moderado'),
  rapido('fast', 'Rápido');

  final String valorApi;
  final String rotulo;
  const Ritmo(this.valorApi, this.rotulo);

  /// Variação semanal em kg (igual ao backend). No ganho o ritmo é menor.
  double kgPorSemana(Objetivo objetivo) => switch ((objetivo, this)) {
        (Objetivo.emagrecer, Ritmo.lento) => 0.25,
        (Objetivo.emagrecer, Ritmo.moderado) => 0.5,
        (Objetivo.emagrecer, Ritmo.rapido) => 0.75,
        (Objetivo.ganhar, Ritmo.lento) => 0.125,
        (Objetivo.ganhar, Ritmo.moderado) => 0.25,
        (Objetivo.ganhar, Ritmo.rapido) => 0.5,
        _ => 0,
      };

  static Ritmo? deApi(String? v) => values.where((r) => r.valorApi == v).firstOrNull;
}

enum Refeicao {
  cafeDaManha('breakfast', 'Café da manhã', Icons.free_breakfast_rounded),
  lancheDaManha('morning_snack', 'Lanche da manhã', Icons.apple_rounded),
  almoco('lunch', 'Almoço', Icons.lunch_dining_rounded),
  lancheDaTarde('afternoon_snack', 'Lanche da tarde', Icons.bakery_dining_rounded),
  jantar('dinner', 'Jantar', Icons.dinner_dining_rounded),
  ceia('supper', 'Ceia', Icons.nightlight_round);

  final String valorApi;
  final String rotulo;
  final IconData icone;
  const Refeicao(this.valorApi, this.rotulo, this.icone);

  static Refeicao deApi(String v) => values.firstWhere((r) => r.valorApi == v, orElse: () => Refeicao.almoco);

  /// Refeição sugerida pelo horário atual.
  static Refeicao peloHorario(DateTime agora) => switch (agora.hour) {
        < 9 => cafeDaManha,
        < 11 => lancheDaManha,
        < 15 => almoco,
        < 18 => lancheDaTarde,
        < 21 => jantar,
        _ => ceia,
      };
}

class PlanoNutricional {
  final int tmb;
  final int gastoTotal;
  final int calorias;
  final int proteinaG;
  final int carboidratoG;
  final int gorduraG;
  final int fibraG;
  final int aguaMl;
  final double imc;
  final int ajusteKcal;
  final double variacaoSemanalKg;
  final bool limitadoPeloMinimo;
  final bool caloriasPersonalizadas;
  final int? semanasAteMeta;

  const PlanoNutricional({
    required this.tmb,
    required this.gastoTotal,
    required this.calorias,
    required this.proteinaG,
    required this.carboidratoG,
    required this.gorduraG,
    required this.fibraG,
    required this.aguaMl,
    required this.imc,
    required this.ajusteKcal,
    required this.variacaoSemanalKg,
    required this.limitadoPeloMinimo,
    required this.caloriasPersonalizadas,
    this.semanasAteMeta,
  });

  factory PlanoNutricional.fromJson(Map<String, dynamic> j) => PlanoNutricional(
        tmb: (j['bmr'] as num).toInt(),
        gastoTotal: (j['tdee'] as num).toInt(),
        calorias: (j['calories'] as num).toInt(),
        proteinaG: (j['protein_g'] as num).toInt(),
        carboidratoG: (j['carbs_g'] as num).toInt(),
        gorduraG: (j['fat_g'] as num).toInt(),
        fibraG: (j['fiber_g'] as num).toInt(),
        aguaMl: (j['water_ml'] as num).toInt(),
        imc: _num(j['bmi']),
        ajusteKcal: (j['adjustment_kcal'] as num).toInt(),
        variacaoSemanalKg: _num(j['weekly_change_kg']),
        limitadoPeloMinimo: j['limited_by_minimum'] == true,
        caloriasPersonalizadas: j['custom_calories'] == true,
        semanasAteMeta: (j['weeks_to_target'] as num?)?.toInt(),
      );

  /// Faixa do IMC segundo a OMS.
  String get classificacaoImc => switch (imc) {
        < 18.5 => 'Abaixo do peso',
        < 25 => 'Peso adequado',
        < 30 => 'Sobrepeso',
        < 35 => 'Obesidade grau I',
        < 40 => 'Obesidade grau II',
        _ => 'Obesidade grau III',
      };
}

class PerfilNutricional {
  final Sexo? sexo;
  final DateTime? nascimento;
  final int? idade;
  final double? alturaCm;
  final NivelAtividade? atividade;
  final Objetivo? objetivo;
  final Ritmo? ritmo;
  final double? pesoMetaKg;
  final int? caloriasManuais;
  final double? pesoKg;
  final DateTime? dataPeso;
  final bool completo;
  final PlanoNutricional? plano;

  const PerfilNutricional({
    this.sexo,
    this.nascimento,
    this.idade,
    this.alturaCm,
    this.atividade,
    this.objetivo,
    this.ritmo,
    this.pesoMetaKg,
    this.caloriasManuais,
    this.pesoKg,
    this.dataPeso,
    this.completo = false,
    this.plano,
  });

  factory PerfilNutricional.fromJson(Map<String, dynamic> j) => PerfilNutricional(
        sexo: Sexo.deApi(j['sex'] as String?),
        nascimento: j['birth_date'] == null ? null : _lerData(j['birth_date'] as String),
        idade: (j['age'] as num?)?.toInt(),
        alturaCm: (j['height_cm'] as num?)?.toDouble(),
        atividade: NivelAtividade.deApi(j['activity_level'] as String?),
        objetivo: Objetivo.deApi(j['goal'] as String?),
        ritmo: Ritmo.deApi(j['goal_pace'] as String?),
        pesoMetaKg: (j['target_weight_kg'] as num?)?.toDouble(),
        caloriasManuais: (j['calorie_override'] as num?)?.toInt(),
        pesoKg: (j['weight_kg'] as num?)?.toDouble(),
        dataPeso: j['weight_date'] == null ? null : _lerData(j['weight_date'] as String),
        completo: j['complete'] == true,
        plano: j['plan'] == null ? null : PlanoNutricional.fromJson(j['plan'] as Map<String, dynamic>),
      );
}

/// Respostas do questionário, enviadas para PUT /profile.
class RespostasPerfil {
  final Sexo sexo;
  final DateTime nascimento;
  final double alturaCm;

  /// Peso a registrar hoje. Nulo mantém o peso já salvo.
  final double? pesoKg;
  final NivelAtividade atividade;
  final Objetivo objetivo;
  final Ritmo? ritmo;
  final double? pesoMetaKg;
  final int? caloriasManuais;

  const RespostasPerfil({
    required this.sexo,
    required this.nascimento,
    required this.alturaCm,
    this.pesoKg,
    required this.atividade,
    required this.objetivo,
    this.ritmo,
    this.pesoMetaKg,
    this.caloriasManuais,
  });

  /// Mesmo perfil, trocando só as calorias manuais (nulo = volta para a meta calculada).
  static RespostasPerfil comCalorias(PerfilNutricional perfil, int? calorias) => RespostasPerfil(
        sexo: perfil.sexo!,
        nascimento: perfil.nascimento!,
        alturaCm: perfil.alturaCm!,
        atividade: perfil.atividade!,
        objetivo: perfil.objetivo!,
        ritmo: perfil.ritmo,
        pesoMetaKg: perfil.pesoMetaKg,
        caloriasManuais: calorias,
      );

  Map<String, dynamic> toJson({DateTime? hoje}) => {
        'sex': sexo.valorApi,
        'birth_date': dataParaApi(nascimento),
        'height_cm': alturaCm,
        'activity_level': atividade.valorApi,
        'goal': objetivo.valorApi,
        'goal_pace': objetivo == Objetivo.manter ? null : (ritmo ?? Ritmo.moderado).valorApi,
        'target_weight_kg': pesoMetaKg,
        'calorie_override': caloriasManuais,
        if (pesoKg != null) ...{
          'weight_kg': pesoKg,
          'weight_date': dataParaApi(hoje ?? DateTime.now()),
        },
      };
}

class RegistroPeso {
  final int id;
  final DateTime data;
  final double pesoKg;

  const RegistroPeso({required this.id, required this.data, required this.pesoKg});

  factory RegistroPeso.fromJson(Map<String, dynamic> j) => RegistroPeso(
        id: (j['id'] as num).toInt(),
        data: _lerData(j['date'] as String),
        pesoKg: _num(j['weight_kg']),
      );
}

class Porcao {
  final String rotulo;
  final double gramas;

  const Porcao(this.rotulo, this.gramas);

  factory Porcao.fromJson(Map<String, dynamic> j) => Porcao(j['label'] as String, _num(j['grams']));
}

/// Calorias e macros (em gramas) de uma quantidade de comida.
class Nutrientes {
  final double kcal;
  final double proteina;
  final double carboidrato;
  final double gordura;
  final double fibra;

  const Nutrientes({this.kcal = 0, this.proteina = 0, this.carboidrato = 0, this.gordura = 0, this.fibra = 0});

  factory Nutrientes.fromJson(Map<String, dynamic> j) => Nutrientes(
        kcal: _num(j['kcal']),
        proteina: _num(j['protein']),
        carboidrato: _num(j['carbs']),
        gordura: _num(j['fat']),
        fibra: _num(j['fiber']),
      );

  Nutrientes vezes(double fator) => Nutrientes(
        kcal: kcal * fator,
        proteina: proteina * fator,
        carboidrato: carboidrato * fator,
        gordura: gordura * fator,
        fibra: fibra * fator,
      );
}

class Alimento {
  final String id;
  final String nome;
  final String categoria;
  final String origem;

  /// Valores por 100 g.
  final Nutrientes por100g;
  final List<Porcao> porcoes;

  const Alimento({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.origem,
    required this.por100g,
    this.porcoes = const [],
  });

  bool get personalizado => origem == 'custom';

  factory Alimento.fromJson(Map<String, dynamic> j) => Alimento(
        id: j['id'] as String,
        nome: j['name'] as String,
        categoria: j['category'] as String? ?? '',
        origem: j['source'] as String? ?? 'taco',
        por100g: Nutrientes.fromJson(j),
        porcoes: [for (final p in (j['portions'] as List? ?? [])) Porcao.fromJson(p as Map<String, dynamic>)],
      );

  Nutrientes para(double gramas) => por100g.vezes(gramas / 100);
}

/// Dados de um alimento cadastrado pelo usuário, como estão no rótulo (por porção).
class NovoAlimento {
  final String nome;
  final double porcaoGramas;
  final String? rotuloPorcao;
  final Nutrientes porPorcao;

  const NovoAlimento({required this.nome, required this.porcaoGramas, this.rotuloPorcao, required this.porPorcao});

  Map<String, dynamic> toJson() => {
        'name': nome,
        'serving_grams': porcaoGramas,
        'serving_label': rotuloPorcao,
        'kcal': porPorcao.kcal,
        'protein': porPorcao.proteina,
        'carbs': porPorcao.carboidrato,
        'fat': porPorcao.gordura,
        'fiber': porPorcao.fibra,
      };
}

class RegistroAlimento {
  final int id;
  final DateTime data;
  final Refeicao refeicao;
  final String alimentoId;
  final String nome;
  final double gramas;
  final String? rotuloPorcao;
  final Nutrientes totais;

  const RegistroAlimento({
    required this.id,
    required this.data,
    required this.refeicao,
    required this.alimentoId,
    required this.nome,
    required this.gramas,
    this.rotuloPorcao,
    required this.totais,
  });

  factory RegistroAlimento.fromJson(Map<String, dynamic> j) => RegistroAlimento(
        id: (j['id'] as num).toInt(),
        data: _lerData(j['date'] as String),
        refeicao: Refeicao.deApi(j['meal'] as String),
        alimentoId: j['food_id'] as String,
        nome: j['name'] as String,
        gramas: _num(j['grams']),
        rotuloPorcao: j['portion_label'] as String?,
        totais: Nutrientes.fromJson(j['totals'] as Map<String, dynamic>),
      );
}

class RefeicaoDoDia {
  final Refeicao refeicao;
  final Nutrientes totais;
  final List<RegistroAlimento> itens;

  const RefeicaoDoDia({required this.refeicao, required this.totais, required this.itens});

  factory RefeicaoDoDia.fromJson(Map<String, dynamic> j) => RefeicaoDoDia(
        refeicao: Refeicao.deApi(j['meal'] as String),
        totais: Nutrientes.fromJson(j['totals'] as Map<String, dynamic>),
        itens: [for (final e in j['entries'] as List) RegistroAlimento.fromJson(e as Map<String, dynamic>)],
      );
}

class DiaDieta {
  final DateTime data;
  final PlanoNutricional? plano;
  final Nutrientes totais;
  final List<RefeicaoDoDia> refeicoes;

  const DiaDieta({required this.data, this.plano, required this.totais, required this.refeicoes});

  factory DiaDieta.fromJson(Map<String, dynamic> j) => DiaDieta(
        data: _lerData(j['date'] as String),
        plano: j['plan'] == null ? null : PlanoNutricional.fromJson(j['plan'] as Map<String, dynamic>),
        totais: Nutrientes.fromJson(j['totals'] as Map<String, dynamic>),
        refeicoes: [for (final m in j['meals'] as List) RefeicaoDoDia.fromJson(m as Map<String, dynamic>)],
      );
}
