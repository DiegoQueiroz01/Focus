import 'dart:math' as math;

import 'package:focus/models/dieta.dart' show dataParaApi;

/// Apps de relógio cujos dados têm prioridade quando o Health Connect tem mais de uma fonte
/// para o mesmo tipo (ex.: passos do relógio e do celular). Fitbeing = com.watchic.app.
const fontesDoRelogio = ['com.watchic'];

/// Meta diária de passos usada na barra de progresso.
const metaPassosPadrao = 10000;

/// Resumo de um dia vindo do relógio. Campos nulos = o relógio não mediu aquilo no dia.
class ResumoSaudeDia {
  final DateTime data;
  final int? passos;
  final double? distanciaMetros;
  final int? calorias;
  final int? frequenciaRepouso;
  final int? frequenciaMedia;
  final int? frequenciaMinima;
  final int? frequenciaMaxima;

  /// Média por intervalo: (minuto do dia, bpm).
  final List<(int, int)> serieFrequencia;
  final int? sonoMinutos;
  final int? sonoProfundoMinutos;
  final int? sonoLeveMinutos;
  final int? sonoRemMinutos;
  final int? sonoAcordadoMinutos;
  final DateTime? dormiuEm;
  final DateTime? acordouEm;
  final double? oxigenioMedio;
  final double? oxigenioMinimo;
  final DateTime? sincronizadoEm;

  const ResumoSaudeDia({
    required this.data,
    this.passos,
    this.distanciaMetros,
    this.calorias,
    this.frequenciaRepouso,
    this.frequenciaMedia,
    this.frequenciaMinima,
    this.frequenciaMaxima,
    this.serieFrequencia = const [],
    this.sonoMinutos,
    this.sonoProfundoMinutos,
    this.sonoLeveMinutos,
    this.sonoRemMinutos,
    this.sonoAcordadoMinutos,
    this.dormiuEm,
    this.acordouEm,
    this.oxigenioMedio,
    this.oxigenioMinimo,
    this.sincronizadoEm,
  });

  bool get temSono => (sonoMinutos ?? 0) > 0;
  bool get temFrequencia => frequenciaMedia != null || frequenciaRepouso != null;
  bool get temEstagiosSono =>
      (sonoProfundoMinutos ?? 0) + (sonoLeveMinutos ?? 0) + (sonoRemMinutos ?? 0) > 0;

  bool get vazio =>
      passos == null &&
      distanciaMetros == null &&
      calorias == null &&
      !temFrequencia &&
      !temSono &&
      oxigenioMedio == null;

  factory ResumoSaudeDia.fromJson(Map<String, dynamic> json) {
    final partes = (json['date'] as String).split('-').map(int.parse).toList();
    int? inteiro(String chave) => (json[chave] as num?)?.toInt();
    double? decimal(String chave) => (json[chave] as num?)?.toDouble();
    DateTime? hora(String chave) => json[chave] == null ? null : DateTime.parse(json[chave] as String).toLocal();

    return ResumoSaudeDia(
      data: DateTime(partes[0], partes[1], partes[2]),
      passos: inteiro('steps'),
      distanciaMetros: decimal('distance_m'),
      calorias: inteiro('active_calories'),
      frequenciaRepouso: inteiro('resting_hr'),
      frequenciaMedia: inteiro('avg_hr'),
      frequenciaMinima: inteiro('min_hr'),
      frequenciaMaxima: inteiro('max_hr'),
      serieFrequencia: [
        for (final p in (json['heart_rate_series'] as List<dynamic>? ?? const []).cast<List<dynamic>>())
          ((p[0] as num).toInt(), (p[1] as num).toInt()),
      ],
      sonoMinutos: inteiro('sleep_minutes'),
      sonoProfundoMinutos: inteiro('sleep_deep_minutes'),
      sonoLeveMinutos: inteiro('sleep_light_minutes'),
      sonoRemMinutos: inteiro('sleep_rem_minutes'),
      sonoAcordadoMinutos: inteiro('sleep_awake_minutes'),
      dormiuEm: hora('sleep_start'),
      acordouEm: hora('sleep_end'),
      oxigenioMedio: decimal('spo2_avg'),
      oxigenioMinimo: decimal('spo2_min'),
      sincronizadoEm: hora('synced_at'),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': dataParaApi(data),
        'steps': passos,
        'distance_m': distanciaMetros == null ? null : double.parse(distanciaMetros!.toStringAsFixed(1)),
        'active_calories': calorias,
        'resting_hr': frequenciaRepouso,
        'avg_hr': frequenciaMedia,
        'min_hr': frequenciaMinima,
        'max_hr': frequenciaMaxima,
        'heart_rate_series': serieFrequencia.isEmpty ? null : [for (final (m, b) in serieFrequencia) [m, b]],
        'sleep_minutes': sonoMinutos,
        'sleep_deep_minutes': sonoProfundoMinutos,
        'sleep_light_minutes': sonoLeveMinutos,
        'sleep_rem_minutes': sonoRemMinutos,
        'sleep_awake_minutes': sonoAcordadoMinutos,
        'sleep_start': dormiuEm?.toUtc().toIso8601String(),
        'sleep_end': acordouEm?.toUtc().toIso8601String(),
        'spo2_avg': oxigenioMedio == null ? null : double.parse(oxigenioMedio!.toStringAsFixed(1)),
        'spo2_min': oxigenioMinimo == null ? null : double.parse(oxigenioMinimo!.toStringAsFixed(1)),
      };
}

/// Tipos de dado lidos do Health Connect.
enum TipoAmostra {
  passos,
  distancia,
  caloriasAtivas,
  caloriasTotais,
  frequencia,
  frequenciaRepouso,
  sonoSessao,
  sonoProfundo,
  sonoLeve,
  sonoRem,
  sonoAcordado,
  oxigenio,
}

/// Uma medida lida do Health Connect, já sem os tipos do pacote `health` (facilita testar).
class AmostraSaude {
  final TipoAmostra tipo;
  final DateTime inicio;
  final DateTime fim;
  final double valor;

  /// Pacote do app que gravou o dado (ex.: com.watchic.app).
  final String fonte;

  const AmostraSaude({
    required this.tipo,
    required this.inicio,
    required this.fim,
    required this.valor,
    this.fonte = '',
  });

  bool get doRelogio => fontesDoRelogio.any(fonte.startsWith);
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tamanho de cada ponto do gráfico de frequência cardíaca.
const _intervaloSerieMinutos = 10;

/// Junta as amostras em um resumo por dia (no fuso do aparelho).
///
/// - Quando há dados do relógio para um tipo, os de outras fontes são ignorados, para não
///   somar duas vezes (ex.: passos do relógio + passos do celular).
/// - [passosAgregados] (total do Health Connect por dia, já sem duplicidade) é usado quando
///   não há passos vindos do relógio.
/// - O sono conta para o dia em que a pessoa acordou.
/// - Dias sem nenhuma medida não entram no resultado.
List<ResumoSaudeDia> montarResumosDiarios(
  List<AmostraSaude> amostras, {
  Map<DateTime, int> passosAgregados = const {},
}) {
  final porTipo = <TipoAmostra, List<AmostraSaude>>{};
  for (final a in amostras) {
    (porTipo[a.tipo] ??= <AmostraSaude>[]).add(a);
  }
  for (final tipo in porTipo.keys.toList()) {
    final lista = porTipo[tipo]!;
    if (lista.any((a) => a.doRelogio)) porTipo[tipo] = [for (final a in lista) if (a.doRelogio) a];
  }
  List<AmostraSaude> doTipo(TipoAmostra t) => porTipo[t] ?? const [];

  final dias = <DateTime, _Acumulador>{};
  _Acumulador acc(DateTime d) => dias[_dia(d)] ??= _Acumulador();

  // Passos: os do relógio; sem eles, o total do Health Connect (que não soma fontes repetidas).
  final passos = doTipo(TipoAmostra.passos);
  if (passos.any((a) => a.doRelogio) || passosAgregados.isEmpty) {
    for (final a in passos) {
      acc(a.inicio).passos = (acc(a.inicio).passos ?? 0) + a.valor.round();
    }
  } else {
    for (final MapEntry(:key, :value) in passosAgregados.entries) {
      if (value > 0) acc(key).passos = value;
    }
  }

  for (final a in doTipo(TipoAmostra.distancia)) {
    acc(a.inicio).distancia = (acc(a.inicio).distancia ?? 0) + a.valor;
  }

  // Calorias: ativas; se o relógio só gravar o total, usa o total.
  final calorias = doTipo(TipoAmostra.caloriasAtivas).isNotEmpty
      ? doTipo(TipoAmostra.caloriasAtivas)
      : doTipo(TipoAmostra.caloriasTotais);
  for (final a in calorias) {
    acc(a.inicio).calorias = (acc(a.inicio).calorias ?? 0) + a.valor;
  }

  for (final a in doTipo(TipoAmostra.frequencia)) {
    if (a.valor < 20 || a.valor > 250) continue;
    acc(a.inicio).frequencias.add((a.inicio, a.valor));
  }

  final repouso = [...doTipo(TipoAmostra.frequenciaRepouso)]..sort((a, b) => a.inicio.compareTo(b.inicio));
  for (final a in repouso) {
    if (a.valor < 20 || a.valor > 250) continue;
    acc(a.inicio).repouso = a.valor.round(); // fica o último do dia
  }

  for (final a in doTipo(TipoAmostra.oxigenio)) {
    final percentual = a.valor <= 1 ? a.valor * 100 : a.valor;
    if (percentual < 50 || percentual > 100) continue;
    acc(a.inicio).oxigenio.add(percentual);
  }

  _agruparSono(porTipo, acc);

  final resultado = <ResumoSaudeDia>[];
  for (final MapEntry(key: dia, value: a) in dias.entries) {
    final resumo = a.resumo(dia);
    if (!resumo.vazio) resultado.add(resumo);
  }
  resultado.sort((a, b) => a.data.compareTo(b.data));
  return resultado;
}

void _agruparSono(Map<TipoAmostra, List<AmostraSaude>> porTipo, _Acumulador Function(DateTime) acc) {
  final sessoes = [...porTipo[TipoAmostra.sonoSessao] ?? const <AmostraSaude>[]]
    ..sort((a, b) => a.inicio.compareTo(b.inicio));

  // Cada estágio vai para o dia da sessão que o contém (ou, sem sessão, para o dia em que termina).
  DateTime diaDoEstagio(AmostraSaude estagio) {
    for (final s in sessoes) {
      if (!estagio.inicio.isBefore(s.inicio) && !estagio.fim.isAfter(s.fim)) return _dia(s.fim);
    }
    return _dia(estagio.fim);
  }

  int minutos(AmostraSaude a) => a.fim.difference(a.inicio).inMinutes;

  const estagios = [TipoAmostra.sonoProfundo, TipoAmostra.sonoLeve, TipoAmostra.sonoRem, TipoAmostra.sonoAcordado];
  for (final tipo in estagios) {
    for (final e in porTipo[tipo] ?? const <AmostraSaude>[]) {
      final a = acc(diaDoEstagio(e));
      a.estagios[tipo] = (a.estagios[tipo] ?? 0) + minutos(e);
      a.marcarSono(e.inicio, e.fim);
    }
  }
  for (final s in sessoes) {
    final a = acc(s.fim);
    a.minutosSessao += minutos(s);
    a.marcarSono(s.inicio, s.fim);
  }
}

class _Acumulador {
  int? passos;
  double? distancia;
  double? calorias;
  int? repouso;
  final frequencias = <(DateTime, double)>[];
  final oxigenio = <double>[];
  final estagios = <TipoAmostra, int>{};
  int minutosSessao = 0;
  DateTime? dormiu;
  DateTime? acordou;

  void marcarSono(DateTime inicio, DateTime fim) {
    if (dormiu == null || inicio.isBefore(dormiu!)) dormiu = inicio;
    if (acordou == null || fim.isAfter(acordou!)) acordou = fim;
  }

  ResumoSaudeDia resumo(DateTime dia) {
    final bpm = [for (final (_, v) in frequencias) v];
    final acordado = estagios[TipoAmostra.sonoAcordado] ?? 0;
    final dormindoPorEstagios = (estagios[TipoAmostra.sonoProfundo] ?? 0) +
        (estagios[TipoAmostra.sonoLeve] ?? 0) +
        (estagios[TipoAmostra.sonoRem] ?? 0);
    // Tempo dormindo = sessão menos o tempo acordado; sem sessão, a soma dos estágios.
    final sono = minutosSessao > 0 ? math.max(0, minutosSessao - acordado) : dormindoPorEstagios;
    int? estagio(TipoAmostra t) => estagios.containsKey(t) ? estagios[t] : null;

    return ResumoSaudeDia(
      data: dia,
      passos: passos == null ? null : math.min(passos!, 200000),
      distanciaMetros: distancia,
      calorias: calorias?.round(),
      frequenciaRepouso: repouso,
      frequenciaMedia: bpm.isEmpty ? null : (bpm.reduce((a, b) => a + b) / bpm.length).round(),
      frequenciaMinima: bpm.isEmpty ? null : bpm.reduce(math.min).round(),
      frequenciaMaxima: bpm.isEmpty ? null : bpm.reduce(math.max).round(),
      serieFrequencia: _serie(),
      sonoMinutos: sono > 0 ? math.min(sono, 24 * 60) : null,
      sonoProfundoMinutos: estagio(TipoAmostra.sonoProfundo),
      sonoLeveMinutos: estagio(TipoAmostra.sonoLeve),
      sonoRemMinutos: estagio(TipoAmostra.sonoRem),
      sonoAcordadoMinutos: estagio(TipoAmostra.sonoAcordado),
      dormiuEm: sono > 0 ? dormiu : null,
      acordouEm: sono > 0 ? acordou : null,
      oxigenioMedio: oxigenio.isEmpty ? null : oxigenio.reduce((a, b) => a + b) / oxigenio.length,
      oxigenioMinimo: oxigenio.isEmpty ? null : oxigenio.reduce(math.min),
    );
  }

  /// Média da frequência em blocos de [_intervaloSerieMinutos] minutos.
  List<(int, int)> _serie() {
    final blocos = <int, List<double>>{};
    for (final (hora, bpm) in frequencias) {
      final minuto = hora.hour * 60 + hora.minute;
      (blocos[minuto - minuto % _intervaloSerieMinutos] ??= <double>[]).add(bpm);
    }
    final chaves = blocos.keys.toList()..sort();
    return [
      for (final k in chaves) (k, (blocos[k]!.reduce((a, b) => a + b) / blocos[k]!.length).round()),
    ];
  }
}
