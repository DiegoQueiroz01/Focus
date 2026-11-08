import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Atividades ao ar livre que podem ser gravadas pelo GPS.
enum TipoAtividadeGps {
  corrida('run', 'Corrida', Icons.directions_run_rounded, 9.8),
  caminhada('walk', 'Caminhada', Icons.directions_walk_rounded, 3.5),
  corridaTrilha('trail_run', 'Corrida em trilha', Icons.terrain_rounded, 10.0),
  trilha('hike', 'Trilha / hiking', Icons.hiking_rounded, 6.0),
  ciclismo('ride', 'Ciclismo', Icons.directions_bike_rounded, 7.5),
  mountainBike('mountain_bike', 'Mountain bike', Icons.pedal_bike_rounded, 8.5),
  patins('inline_skate', 'Patins', Icons.roller_skating_rounded, 7.5);

  final String api;
  final String rotulo;
  final IconData icone;

  /// Gasto energético médio (MET), igual ao usado no servidor.
  final double met;

  const TipoAtividadeGps(this.api, this.rotulo, this.icone, this.met);

  /// Pedal e patins mostram velocidade (km/h); as demais, ritmo (min/km).
  bool get usaVelocidade => this == ciclismo || this == mountainBike || this == patins;

  static TipoAtividadeGps fromApi(String? valor) =>
      values.firstWhere((t) => t.api == valor, orElse: () => corrida);

  /// Estimativa com 70 kg, a mesma do servidor enquanto o perfil não guarda o peso.
  int estimarCalorias(int segundosEmMovimento) => (met * 70 * segundosEmMovimento / 3600).round();
}

/// Um ponto gravado: posição, altitude (quando o GPS informa) e segundos desde o início.
class PontoGps {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double segundos;

  const PontoGps(this.latitude, this.longitude, this.altitude, this.segundos);

  LatLng get latLng => LatLng(latitude, longitude);

  List<double?> toJson() => [latitude, longitude, altitude, segundos];

  factory PontoGps.fromJson(List<dynamic> json) => PontoGps(
        (json[0] as num).toDouble(),
        (json[1] as num).toDouble(),
        (json[2] as num?)?.toDouble(),
        (json[3] as num?)?.toDouble() ?? 0,
      );
}

class AtividadeGps {
  /// Nulo enquanto a atividade ainda não foi salva no servidor.
  final int? id;
  final TipoAtividadeGps tipo;
  final DateTime iniciadaEm;
  final DateTime finalizadaEm;
  final int tempoTotalSegundos;
  final int tempoMovimentoSegundos;
  final double distanciaMetros;
  final double ganhoElevacao;
  final double perdaElevacao;
  final double velocidadeMaximaMps;
  final int calorias;
  final String? comentario;

  /// Pontos completos (detalhe) ou vazio (itens da lista, que só trazem a prévia).
  final List<PontoGps> pontos;

  /// Trajeto para desenhar no mapa: os pontos completos ou a prévia simplificada.
  final List<LatLng> trajeto;

  /// Segundos gastos em cada km completo.
  final List<int> parciais;

  const AtividadeGps({
    this.id,
    required this.tipo,
    required this.iniciadaEm,
    required this.finalizadaEm,
    required this.tempoTotalSegundos,
    required this.tempoMovimentoSegundos,
    required this.distanciaMetros,
    this.ganhoElevacao = 0,
    this.perdaElevacao = 0,
    this.velocidadeMaximaMps = 0,
    this.calorias = 0,
    this.comentario,
    this.pontos = const [],
    this.trajeto = const [],
    this.parciais = const [],
  });

  double get distanciaKm => distanciaMetros / 1000;

  /// Segundos por km, com base no tempo em movimento. Nulo sem distância.
  double? get ritmoMedio => distanciaMetros < 10 ? null : tempoMovimentoSegundos / distanciaKm;

  double get velocidadeMediaKmh =>
      tempoMovimentoSegundos == 0 ? 0 : distanciaKm / (tempoMovimentoSegundos / 3600);

  AtividadeGps copiarCom({String? comentario}) => AtividadeGps(
        id: id,
        tipo: tipo,
        iniciadaEm: iniciadaEm,
        finalizadaEm: finalizadaEm,
        tempoTotalSegundos: tempoTotalSegundos,
        tempoMovimentoSegundos: tempoMovimentoSegundos,
        distanciaMetros: distanciaMetros,
        ganhoElevacao: ganhoElevacao,
        perdaElevacao: perdaElevacao,
        velocidadeMaximaMps: velocidadeMaximaMps,
        calorias: calorias,
        comentario: comentario,
        pontos: pontos,
        trajeto: trajeto,
        parciais: parciais,
      );

  factory AtividadeGps.fromJson(Map<String, dynamic> json) {
    final pontos = [
      for (final p in (json['route'] as List<dynamic>? ?? const [])) PontoGps.fromJson(p as List<dynamic>),
    ];
    final previa = [
      for (final p in (json['route_preview'] as List<dynamic>? ?? const []))
        LatLng(((p as List<dynamic>)[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
    return AtividadeGps(
      id: (json['id'] as num).toInt(),
      tipo: TipoAtividadeGps.fromApi(json['activity_type'] as String?),
      iniciadaEm: DateTime.parse(json['started_at'] as String).toLocal(),
      finalizadaEm: DateTime.parse(json['finished_at'] as String).toLocal(),
      tempoTotalSegundos: (json['elapsed_seconds'] as num).toInt(),
      tempoMovimentoSegundos: (json['moving_seconds'] as num).toInt(),
      distanciaMetros: (json['distance_m'] as num).toDouble(),
      ganhoElevacao: (json['elevation_gain_m'] as num?)?.toDouble() ?? 0,
      perdaElevacao: (json['elevation_loss_m'] as num?)?.toDouble() ?? 0,
      velocidadeMaximaMps: (json['max_speed_mps'] as num?)?.toDouble() ?? 0,
      calorias: (json['calories'] as num?)?.toInt() ?? 0,
      comentario: json['comment'] as String?,
      pontos: pontos,
      trajeto: pontos.isNotEmpty ? [for (final p in pontos) p.latLng] : previa,
      parciais: [for (final s in (json['splits'] as List<dynamic>? ?? const [])) (s as num).toInt()],
    );
  }

  Map<String, dynamic> toJson() => {
        'activity_type': tipo.api,
        'started_at': iniciadaEm.toUtc().toIso8601String(),
        'finished_at': finalizadaEm.toUtc().toIso8601String(),
        'elapsed_seconds': tempoTotalSegundos,
        'moving_seconds': tempoMovimentoSegundos,
        'distance_m': distanciaMetros,
        'elevation_gain_m': ganhoElevacao,
        'elevation_loss_m': perdaElevacao,
        'max_speed_mps': velocidadeMaximaMps,
        'comment': comentario,
        'route': [for (final p in pontos) p.toJson()],
        'splits': parciais,
      };
}
