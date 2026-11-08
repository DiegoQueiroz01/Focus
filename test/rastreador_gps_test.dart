import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/service/rastreador_gps.dart';
import 'package:focus/utils/formatadores.dart';

/// Metros por grau de latitude (aproximado; os testes usam tolerância).
const _mPorGrau = 110600.0;

class _FonteVazia implements FonteLocalizacao {
  @override
  Future<String?> preparar() async => null;

  @override
  Stream<LeituraGps> leituras() => const Stream.empty();
}

void main() {
  late DateTime agora;
  late RastreadorGps rastreador;

  LeituraGps leitura(double metrosAoNorte, {double? altitude, double precisao = 4}) => LeituraGps(
        latitude: -13 + metrosAoNorte / _mPorGrau,
        longitude: -38.5,
        altitude: altitude,
        precisao: precisao,
        horario: agora,
      );

  void avancar(int segundos) => agora = agora.add(Duration(seconds: segundos));

  setUp(() {
    agora = DateTime(2026, 11, 8, 6);
    rastreador = RastreadorGps(tipo: TipoAtividadeGps.corrida, fonte: _FonteVazia(), relogio: () => agora);
  });

  tearDown(() => rastreador.dispose());

  test('soma distância, tempo em movimento e parciais por km', () {
    rastreador.registrar(leitura(0));
    rastreador.iniciar();
    for (var s = 1; s <= 700; s++) {
      avancar(1);
      rastreador.registrar(leitura(s * 3.0));
    }

    expect(rastreador.distancia, closeTo(2100, 25));
    expect(rastreador.segundosEmMovimento, 700);
    expect(rastreador.parciais, hasLength(2));
    expect(rastreador.parciais.first, closeTo(333, 5));
    expect(rastreador.ritmoMedio, closeTo(333, 5));
    expect(rastreador.velocidadeAtual, closeTo(3, 0.1));

    final atividade = rastreador.finalizar();
    expect(atividade.tempoTotalSegundos, 700);
    expect(atividade.pontos, hasLength(701));
    expect(atividade.calorias, TipoAtividadeGps.corrida.estimarCalorias(700));
  });

  test('pausa não conta tempo nem o trecho percorrido parado', () {
    rastreador.registrar(leitura(0));
    rastreador.iniciar();
    for (var s = 1; s <= 100; s++) {
      avancar(1);
      rastreador.registrar(leitura(s * 3.0));
    }
    rastreador.pausar();
    avancar(120);
    rastreador.registrar(leitura(800)); // durante a pausa: ignorado
    rastreador.retomar();
    rastreador.registrar(leitura(900)); // primeiro ponto após a pausa: só reinicia o trecho
    avancar(10);
    rastreador.registrar(leitura(930));

    expect(rastreador.distancia, closeTo(330, 5));
    expect(rastreador.tempoAtivo.inSeconds, 110);
    expect(rastreador.finalizar().tempoTotalSegundos, 230);
  });

  test('ignora ruído do GPS parado e leituras imprecisas', () {
    rastreador.registrar(leitura(0));
    rastreador.iniciar();
    for (var s = 1; s <= 60; s++) {
      avancar(1);
      rastreador.registrar(leitura(s.isEven ? 1.5 : -1.5));
    }
    avancar(1);
    rastreador.registrar(leitura(500, precisao: 80));

    expect(rastreador.distancia, 0);
    expect(rastreador.segundosEmMovimento, 0);
    expect(rastreador.ritmoAtual, isNull);
  });

  test('elevação só conta variações acima do limiar', () {
    rastreador.registrar(leitura(0, altitude: 10));
    rastreador.iniciar();
    final altitudes = [11.0, 9.5, 10.8, 14.0, 18.0, 20.0, 16.0, 12.0];
    for (final (i, alt) in altitudes.indexed) {
      avancar(2);
      rastreador.registrar(leitura((i + 1) * 6.0, altitude: alt));
    }

    // 10→14→18 conta (+8); 18→12 conta (−6); oscilações menores que 3 m não.
    expect(rastreador.ganhoElevacao, closeTo(8, 0.01));
    expect(rastreador.perdaElevacao, closeTo(6, 0.01));
  });

  test('atividade vai e volta do JSON da API', () {
    final atividade = AtividadeGps(
      id: 7,
      tipo: TipoAtividadeGps.ciclismo,
      iniciadaEm: DateTime.utc(2026, 11, 8, 9),
      finalizadaEm: DateTime.utc(2026, 11, 8, 10),
      tempoTotalSegundos: 3600,
      tempoMovimentoSegundos: 3400,
      distanciaMetros: 25000,
      calorias: 496,
      pontos: const [PontoGps(-13, -38.5, 10, 0), PontoGps(-13.001, -38.5, null, 5)],
      parciais: const [140, 138],
    );
    final volta = AtividadeGps.fromJson({...atividade.toJson(), 'id': 7, 'calories': 496});

    expect(volta.tipo, TipoAtividadeGps.ciclismo);
    expect(volta.pontos[1].altitude, isNull);
    expect(volta.trajeto, hasLength(2));
    expect(volta.velocidadeMediaKmh, closeTo(26.5, 0.1));
    expect(volta.parciais, [140, 138]);
  });

  test('formatadores de GPS', () {
    expect(formatarDistancia(850), '850 m');
    expect(formatarDistancia(5234), '5,23 km');
    expect(formatarRitmo(342), '5:42');
    expect(formatarRitmo(null), '--:--');
    expect(formatarVelocidade(23.44), '23,4 km/h');
  });
}
