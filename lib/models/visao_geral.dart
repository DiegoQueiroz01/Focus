/// Dados do painel: totais da semana atual, sequência de dias e mapa de atividades.
class VisaoGeral {
  final ResumoSemana semana;
  final Sequencia sequencia;
  final MapaDeAtividades mapa;

  const VisaoGeral({required this.semana, required this.sequencia, required this.mapa});

  factory VisaoGeral.fromJson(Map<String, dynamic> json) {
    return VisaoGeral(
      semana: ResumoSemana.fromJson(json['week'] as Map<String, dynamic>),
      sequencia: Sequencia.fromJson(json['streak'] as Map<String, dynamic>),
      mapa: MapaDeAtividades.fromJson(json['heatmap'] as Map<String, dynamic>),
    );
  }
}

/// "2026-11-08" → DateTime local à meia-noite.
DateTime _lerData(Object? valor) {
  final data = DateTime.parse(valor as String);
  return DateTime(data.year, data.month, data.day);
}

class TotaisDoDia {
  final DateTime data;
  final int sessoes;
  final int duracaoSegundos;
  final double volumeKg;
  final int series;

  const TotaisDoDia({
    required this.data,
    required this.sessoes,
    required this.duracaoSegundos,
    required this.volumeKg,
    required this.series,
  });

  factory TotaisDoDia.fromJson(Map<String, dynamic> json) {
    return TotaisDoDia(
      data: _lerData(json['date']),
      sessoes: (json['sessions'] as num).toInt(),
      duracaoSegundos: (json['duration_seconds'] as num).toInt(),
      volumeKg: (json['volume_kg'] as num).toDouble(),
      series: (json['sets'] as num).toInt(),
    );
  }
}

class ResumoSemana {
  final DateTime inicio;
  final DateTime fim;
  final int totalSessoes;
  final int totalSegundos;
  final double totalVolumeKg;
  final int totalSeries;
  final List<TotaisDoDia> dias;

  const ResumoSemana({
    required this.inicio,
    required this.fim,
    required this.totalSessoes,
    required this.totalSegundos,
    required this.totalVolumeKg,
    required this.totalSeries,
    required this.dias,
  });

  factory ResumoSemana.fromJson(Map<String, dynamic> json) {
    return ResumoSemana(
      inicio: _lerData(json['start']),
      fim: _lerData(json['end']),
      totalSessoes: (json['total_sessions'] as num).toInt(),
      totalSegundos: (json['total_duration_seconds'] as num).toInt(),
      totalVolumeKg: (json['total_volume_kg'] as num).toDouble(),
      totalSeries: (json['total_sets'] as num).toInt(),
      dias: (json['days'] as List).map((d) => TotaisDoDia.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}

class Sequencia {
  final int atual;
  final int recorde;
  final bool treinouHoje;

  const Sequencia({required this.atual, required this.recorde, required this.treinouHoje});

  factory Sequencia.fromJson(Map<String, dynamic> json) {
    return Sequencia(
      atual: (json['current'] as num).toInt(),
      recorde: (json['best'] as num).toInt(),
      treinouHoje: json['trained_today'] as bool,
    );
  }
}

class MapaDeAtividades {
  final DateTime inicio;
  final DateTime fim;

  /// Quantidade de atividades por dia (só dias com pelo menos uma).
  final Map<DateTime, int> contagemPorDia;

  const MapaDeAtividades({required this.inicio, required this.fim, required this.contagemPorDia});

  int contagem(DateTime dia) => contagemPorDia[DateTime(dia.year, dia.month, dia.day)] ?? 0;

  int get totalAtividades => contagemPorDia.values.fold(0, (soma, c) => soma + c);

  factory MapaDeAtividades.fromJson(Map<String, dynamic> json) {
    return MapaDeAtividades(
      inicio: _lerData(json['start']),
      fim: _lerData(json['end']),
      contagemPorDia: {
        for (final d in json['days'] as List)
          _lerData((d as Map<String, dynamic>)['date']): (d['count'] as num).toInt(),
      },
    );
  }
}
