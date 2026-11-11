import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/saude.dart';

const _relogio = 'com.watchic.app';
const _celular = 'com.google.android.apps.fitness';

AmostraSaude _amostra(TipoAmostra tipo, DateTime inicio, double valor,
        {Duration duracao = const Duration(minutes: 1), String fonte = _relogio}) =>
    AmostraSaude(tipo: tipo, inicio: inicio, fim: inicio.add(duracao), valor: valor, fonte: fonte);

void main() {
  group('montarResumosDiarios', () {
    test('soma passos, distância e calorias por dia', () {
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 8), 3000),
        _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 18), 2500),
        _amostra(TipoAmostra.passos, DateTime(2026, 11, 10, 9), 1000),
        _amostra(TipoAmostra.distancia, DateTime(2026, 11, 9, 8), 2100.5),
        _amostra(TipoAmostra.caloriasAtivas, DateTime(2026, 11, 9, 8), 120.4),
        _amostra(TipoAmostra.caloriasAtivas, DateTime(2026, 11, 9, 18), 99.8),
      ]);

      expect(resumos.map((r) => r.data), [DateTime(2026, 11, 9), DateTime(2026, 11, 10)]);
      expect(resumos[0].passos, 5500);
      expect(resumos[0].distanciaMetros, 2100.5);
      expect(resumos[0].calorias, 220);
      expect(resumos[1].passos, 1000);
    });

    test('com dados do relógio, ignora os de outras fontes', () {
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 8), 4000),
        _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 8), 3800, fonte: _celular),
      ]);
      expect(resumos.single.passos, 4000);
    });

    test('sem passos do relógio, usa o total agregado do Health Connect', () {
      final resumos = montarResumosDiarios(
        [
          _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 8), 3000, fonte: _celular),
          _amostra(TipoAmostra.passos, DateTime(2026, 11, 9, 8), 3000, fonte: 'outro.app'),
        ],
        passosAgregados: {DateTime(2026, 11, 9): 3000},
      );
      expect(resumos.single.passos, 3000);
    });

    test('usa calorias totais quando o relógio não grava as ativas', () {
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.caloriasTotais, DateTime(2026, 11, 9, 8), 1800),
      ]);
      expect(resumos.single.calorias, 1800);
    });

    test('frequência cardíaca: média, mínima, máxima, repouso e série em blocos de 10 min', () {
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.frequencia, DateTime(2026, 11, 9, 7, 1), 60),
        _amostra(TipoAmostra.frequencia, DateTime(2026, 11, 9, 7, 8), 70),
        _amostra(TipoAmostra.frequencia, DateTime(2026, 11, 9, 12, 0), 110),
        _amostra(TipoAmostra.frequencia, DateTime(2026, 11, 9, 12, 5), 300), // leitura inválida
        _amostra(TipoAmostra.frequenciaRepouso, DateTime(2026, 11, 9, 6), 61),
        _amostra(TipoAmostra.frequenciaRepouso, DateTime(2026, 11, 9, 23), 58),
      ]);
      final dia = resumos.single;
      expect(dia.frequenciaMedia, 80);
      expect(dia.frequenciaMinima, 60);
      expect(dia.frequenciaMaxima, 110);
      expect(dia.frequenciaRepouso, 58);
      expect(dia.serieFrequencia, [(420, 65), (720, 110)]);
    });

    test('sono conta para o dia em que a pessoa acordou e desconta o tempo acordado', () {
      final dormiu = DateTime(2026, 11, 8, 23, 30);
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.sonoSessao, dormiu, 0, duracao: const Duration(hours: 8)),
        // O estágio termina antes da meia-noite, mas pertence à noite que acaba no dia 9.
        _amostra(TipoAmostra.sonoLeve, dormiu, 0, duracao: const Duration(minutes: 20)),
        _amostra(TipoAmostra.sonoProfundo, DateTime(2026, 11, 9, 1), 0, duracao: const Duration(minutes: 90)),
        _amostra(TipoAmostra.sonoRem, DateTime(2026, 11, 9, 4), 0, duracao: const Duration(minutes: 60)),
        _amostra(TipoAmostra.sonoAcordado, DateTime(2026, 11, 9, 5), 0, duracao: const Duration(minutes: 15)),
      ]);

      final dia = resumos.single;
      expect(dia.data, DateTime(2026, 11, 9));
      expect(dia.sonoMinutos, 8 * 60 - 15);
      expect(dia.sonoLeveMinutos, 20);
      expect(dia.sonoProfundoMinutos, 90);
      expect(dia.sonoRemMinutos, 60);
      expect(dia.sonoAcordadoMinutos, 15);
      expect(dia.dormiuEm, dormiu);
      expect(dia.acordouEm, DateTime(2026, 11, 9, 7, 30));
    });

    test('oxigênio aceita fração (0,97) ou percentual (97)', () {
      final resumos = montarResumosDiarios([
        _amostra(TipoAmostra.oxigenio, DateTime(2026, 11, 9, 3), 0.95),
        _amostra(TipoAmostra.oxigenio, DateTime(2026, 11, 9, 4), 99),
      ]);
      expect(resumos.single.oxigenioMedio, 97);
      expect(resumos.single.oxigenioMinimo, 95);
    });

    test('dias sem nenhuma medida válida ficam de fora', () {
      expect(montarResumosDiarios([_amostra(TipoAmostra.frequencia, DateTime(2026, 11, 9), 5)]), isEmpty);
    });
  });

  test('ResumoSaudeDia vai e volta da API sem perder dados', () {
    final original = ResumoSaudeDia(
      data: DateTime(2026, 11, 9),
      passos: 8421,
      distanciaMetros: 6120.54,
      frequenciaMedia: 74,
      serieFrequencia: const [(0, 60), (600, 72)],
      sonoMinutos: 430,
      dormiuEm: DateTime(2026, 11, 8, 23, 10),
      oxigenioMedio: 97.24,
    );
    final json = original.toJson();
    expect(json['date'], '2026-11-09');
    expect(json['distance_m'], 6120.5);
    expect(json['heart_rate_series'], [
      [0, 60],
      [600, 72],
    ]);

    final volta = ResumoSaudeDia.fromJson({...json, 'synced_at': '2026-11-10T12:00:00Z'});
    expect(volta.passos, 8421);
    expect(volta.serieFrequencia, original.serieFrequencia);
    expect(volta.dormiuEm, original.dormiuEm);
    expect(volta.oxigenioMedio, 97.2);
  });
}
