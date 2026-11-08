import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Uma leitura de posição, venha do GPS real ou da simulação.
class LeituraGps {
  final double latitude;
  final double longitude;
  final double? altitude;

  /// Raio de incerteza em metros.
  final double precisao;

  /// Velocidade informada pelo aparelho (m/s), quando disponível.
  final double? velocidade;
  final DateTime horario;

  const LeituraGps({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.precisao = 5,
    this.velocidade,
    required this.horario,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

abstract class FonteLocalizacao {
  /// Confere se o GPS está ligado e pede permissão. Retorna a mensagem de erro, ou nulo se estiver tudo certo.
  Future<String?> preparar();

  Stream<LeituraGps> leituras();
}

/// GPS do aparelho. No Android roda como serviço em primeiro plano (com notificação),
/// para continuar gravando com a tela bloqueada; no iPhone usa o modo de localização em segundo plano.
class FonteGeolocator implements FonteLocalizacao {
  const FonteGeolocator();

  @override
  Future<String?> preparar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Ative a localização (GPS) do aparelho para gravar a atividade.';
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    return switch (permissao) {
      LocationPermission.denied => 'Permita o acesso à localização para gravar a atividade.',
      LocationPermission.deniedForever =>
        'O acesso à localização foi negado. Libere nas configurações do aparelho.',
      _ => null,
    };
  }

  @override
  Stream<LeituraGps> leituras() => Geolocator.getPositionStream(locationSettings: _configuracao()).map(
        (p) => LeituraGps(
          latitude: p.latitude,
          longitude: p.longitude,
          // Sem altímetro/fixação 3D o aparelho manda altitude 0 e precisão 0.
          altitude: p.altitude == 0 && p.altitudeAccuracy == 0 ? null : p.altitude,
          precisao: p.accuracy,
          velocidade: p.speed >= 0 ? p.speed : null,
          horario: p.timestamp,
        ),
      );

  LocationSettings _configuracao() {
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.best);
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Focus está gravando sua atividade',
            notificationText: 'O GPS continua ativo com a tela bloqueada.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best),
    };
  }
}

/// Percurso de mentira (uma volta em círculo) para testar as telas no Windows ou no emulador.
class FonteSimulada implements FonteLocalizacao {
  final LatLng centro;
  final double velocidade;
  final double raio;

  const FonteSimulada({
    this.centro = const LatLng(-13.0104, -38.5324),
    this.velocidade = 3,
    this.raio = 450,
  });

  factory FonteSimulada.para(TipoAtividadeGps tipo) => FonteSimulada(
        velocidade: switch (tipo) {
          TipoAtividadeGps.caminhada || TipoAtividadeGps.trilha => 1.4,
          TipoAtividadeGps.ciclismo || TipoAtividadeGps.mountainBike => 7,
          TipoAtividadeGps.patins => 4.5,
          _ => 3,
        },
      );

  @override
  Future<String?> preparar() async => null;

  @override
  Stream<LeituraGps> leituras() {
    final aleatorio = math.Random();
    return Stream.periodic(const Duration(seconds: 1), (i) {
      final angulo = i * velocidade / raio;
      final norte = raio * math.sin(angulo) + aleatorio.nextDouble() - 0.5;
      final leste = raio * (1 - math.cos(angulo)) + aleatorio.nextDouble() - 0.5;
      return LeituraGps(
        latitude: centro.latitude + norte / 111320,
        longitude: centro.longitude + leste / (111320 * math.cos(centro.latitude * math.pi / 180)),
        altitude: 20 + 12 * math.sin(angulo * 2),
        precisao: 4,
        velocidade: velocidade,
        horario: DateTime.now(),
      );
    });
  }
}

enum EstadoGravacao { aguardando, gravando, pausado }

/// Grava uma atividade: junta os pontos e calcula distância, tempos, ritmo,
/// elevação e parciais por km.
class RastreadorGps extends ChangeNotifier {
  final TipoAtividadeGps tipo;
  final FonteLocalizacao fonte;
  final DateTime Function() _agora;

  /// Leituras com incerteza maior que isso são ignoradas no cálculo.
  static const precisaoMaxima = 30.0;

  /// Abaixo dessa velocidade (m/s) o tempo não conta como "em movimento".
  static const velocidadeMinima = 0.5;

  /// Diferença de altitude necessária para contar ganho/perda (filtra o ruído do GPS).
  static const limiarElevacao = 3.0;

  RastreadorGps({required this.tipo, required this.fonte, DateTime Function()? relogio})
      : _agora = relogio ?? DateTime.now;

  StreamSubscription<LeituraGps>? _assinatura;
  Timer? _tique;

  EstadoGravacao estado = EstadoGravacao.aguardando;
  LeituraGps? posicaoAtual;
  String? erro;

  final _pontos = <PontoGps>[];
  final parciais = <int>[];
  double distancia = 0;
  double ganhoElevacao = 0;
  double perdaElevacao = 0;
  double velocidadeMaxima = 0;
  double _segundosEmMovimento = 0;

  DateTime? _inicio;
  DateTime? _pausadoDesde;
  Duration _tempoPausado = Duration.zero;
  LeituraGps? _ultima;
  double _ultimaT = 0;
  double? _altitudeReferencia;
  double _tempoNoUltimoKm = 0;
  bool _novoTrecho = false;

  /// (segundos, distância acumulada) dos últimos instantes, para a velocidade atual.
  final _janela = Queue<(double, double)>();

  List<PontoGps> get pontos => List.unmodifiable(_pontos);
  List<LatLng> get trajeto => [for (final p in _pontos) p.latLng];
  DateTime? get iniciadaEm => _inicio;
  bool get temSinal => posicaoAtual != null && posicaoAtual!.precisao <= precisaoMaxima;

  /// Tempo desde o início, sem as pausas.
  Duration get tempoAtivo {
    if (_inicio == null) return Duration.zero;
    return (_pausadoDesde ?? _agora()).difference(_inicio!) - _tempoPausado;
  }

  int get segundosEmMovimento => _segundosEmMovimento.round();
  int get calorias => tipo.estimarCalorias(segundosEmMovimento);
  double? get altitudeAtual => posicaoAtual?.altitude;

  /// Ritmo médio em segundos por km (tempo em movimento).
  double? get ritmoMedio => distancia < 50 ? null : _segundosEmMovimento / (distancia / 1000);

  /// Velocidade dos últimos ~15 s, em m/s. Zera se o GPS ficar parado.
  double get velocidadeAtual {
    if (estado != EstadoGravacao.gravando || _janela.length < 2) return 0;
    final agora = tempoAtivo.inMilliseconds / 1000;
    if (agora - _ultimaT > 10) return 0;
    final (t0, d0) = _janela.first;
    final (t1, d1) = _janela.last;
    return t1 - t0 < 3 ? 0 : (d1 - d0) / (t1 - t0);
  }

  /// Ritmo atual em segundos por km; nulo quando parado.
  double? get ritmoAtual {
    final v = velocidadeAtual;
    return v < velocidadeMinima ? null : 1000 / v;
  }

  /// Tempo e distância do km em andamento.
  double get distanciaNoKmAtual => distancia - parciais.length * 1000;
  double get segundosNoKmAtual => tempoAtivo.inMilliseconds / 1000 - _tempoNoUltimoKm;

  Future<void> conectar() async {
    erro = await fonte.preparar();
    if (erro != null) {
      notifyListeners();
      return;
    }
    _assinatura = fonte.leituras().listen(
      registrar,
      onError: (Object e) {
        erro = 'O GPS parou de responder: $e';
        notifyListeners();
      },
    );
    // Atualiza o cronômetro mesmo sem novas leituras.
    _tique = Timer.periodic(const Duration(seconds: 1), (_) {
      if (estado == EstadoGravacao.gravando) notifyListeners();
    });
  }

  void iniciar() {
    _inicio = _agora();
    estado = EstadoGravacao.gravando;
    if (temSinal) _adicionarPonto(posicaoAtual!, 0);
    notifyListeners();
  }

  void pausar() {
    if (estado != EstadoGravacao.gravando) return;
    _pausadoDesde = _agora();
    estado = EstadoGravacao.pausado;
    notifyListeners();
  }

  void retomar() {
    if (estado != EstadoGravacao.pausado) return;
    _tempoPausado += _agora().difference(_pausadoDesde!);
    _pausadoDesde = null;
    // O trecho percorrido durante a pausa não entra na distância.
    _novoTrecho = true;
    _janela.clear();
    estado = EstadoGravacao.gravando;
    notifyListeners();
  }

  @visibleForTesting
  void registrar(LeituraGps leitura) {
    posicaoAtual = leitura;
    if (estado == EstadoGravacao.gravando && leitura.precisao <= precisaoMaxima) {
      _processar(leitura);
    }
    notifyListeners();
  }

  void _processar(LeituraGps leitura) {
    final t = tempoAtivo.inMilliseconds / 1000;
    final anterior = _ultima;
    if (anterior == null || _novoTrecho) {
      _novoTrecho = false;
      _adicionarPonto(leitura, t);
      return;
    }

    final dt = t - _ultimaT;
    if (dt <= 0) return;
    final d = const Distance().as(LengthUnit.Meter, anterior.latLng, leitura.latLng);
    // Parado: o GPS "anda" alguns metros sozinho, então movimentos pequenos são ignorados.
    if (d < math.max(3, leitura.precisao / 2)) return;
    final v = d / dt;
    // Saltos impossíveis (> 216 km/h) são erro do GPS.
    if (v > 60) return;

    final distanciaAntes = distancia;
    distancia += d;
    if (v >= velocidadeMinima) _segundosEmMovimento += dt;
    final vMedida = leitura.velocidade ?? v;
    if (vMedida <= 60) velocidadeMaxima = math.max(velocidadeMaxima, vMedida);

    // Parciais: interpola o instante em que cada km foi completado.
    while (distancia >= (parciais.length + 1) * 1000) {
      final marca = (parciais.length + 1) * 1000;
      final instante = _ultimaT + dt * (marca - distanciaAntes) / d;
      parciais.add((instante - _tempoNoUltimoKm).round());
      _tempoNoUltimoKm = instante;
    }

    _adicionarPonto(leitura, t);
  }

  void _adicionarPonto(LeituraGps leitura, double t) {
    final altitude = leitura.altitude;
    if (altitude != null) {
      final referencia = _altitudeReferencia;
      if (referencia == null) {
        _altitudeReferencia = altitude;
      } else if (altitude - referencia >= limiarElevacao) {
        ganhoElevacao += altitude - referencia;
        _altitudeReferencia = altitude;
      } else if (referencia - altitude >= limiarElevacao) {
        perdaElevacao += referencia - altitude;
        _altitudeReferencia = altitude;
      }
    }

    _pontos.add(PontoGps(leitura.latitude, leitura.longitude, altitude, t));
    _ultima = leitura;
    _ultimaT = t;
    _janela.addLast((t, distancia));
    while (_janela.length > 2 && t - _janela.first.$1 > 15) {
      _janela.removeFirst();
    }
  }

  /// Encerra a gravação e devolve a atividade pronta para o resumo.
  AtividadeGps finalizar() {
    final fim = _agora();
    final inicio = _inicio ?? fim;
    _parar();
    final total = fim.difference(inicio).inSeconds;
    final movimento = math.min(segundosEmMovimento, total);
    return AtividadeGps(
      tipo: tipo,
      iniciadaEm: inicio,
      finalizadaEm: fim,
      tempoTotalSegundos: total,
      tempoMovimentoSegundos: movimento,
      distanciaMetros: distancia,
      ganhoElevacao: ganhoElevacao,
      perdaElevacao: perdaElevacao,
      velocidadeMaximaMps: velocidadeMaxima,
      calorias: tipo.estimarCalorias(movimento),
      pontos: List.of(_pontos),
      trajeto: trajeto,
      parciais: List.of(parciais),
    );
  }

  void _parar() {
    _assinatura?.cancel();
    _assinatura = null;
    _tique?.cancel();
    _tique = null;
  }

  @override
  void dispose() {
    _parar();
    super.dispose();
  }
}
