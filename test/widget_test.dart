import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/pagina.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/models/visao_geral.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/utils/validadores.dart';
import 'package:focus/views/cadastro_screen.dart';
import 'package:focus/views/login_screen.dart';
import 'package:focus/widgets/mapa_atividades.dart';

void main() {
  group('Treino', () {
    final json = {
      'id': 7,
      'name': 'Treino A',
      'type': 'strength',
      'created_at': '2026-11-03T14:00:00Z',
      'total_sets': 8,
      'exercises': [
        {'id': 1, 'name': 'Supino', 'muscle_group': 'chest', 'sets': 4, 'reps': 10, 'weight_kg': 30.0},
        {'id': 2, 'name': 'Tríceps corda', 'muscle_group': 'triceps', 'sets': 4, 'reps': 12, 'weight_kg': 14.5},
      ],
    };

    test('fromJson converte o payload da API', () {
      final treino = Treino.fromJson(json);

      expect(treino.id, 7);
      expect(treino.tipo, TipoTreino.musculacao);
      expect(treino.seriesTotais, 8);
      expect(treino.criadoEm!.isUtc, isFalse);
      expect(treino.exercicios.first.grupoMuscular, GrupoMuscular.peito);
      expect(treino.gruposMusculares, [GrupoMuscular.peito, GrupoMuscular.triceps]);
      expect(treino.exercicios.last.cargaFormatada, '14.5 kg');
    });

    test('toJson gera o payload esperado pelo POST/PUT /workouts', () {
      final payload = Treino.fromJson(json).toJson();

      expect(payload.keys, containsAll(['name', 'type', 'exercises']));
      expect((payload['exercises'] as List).first, {
        'name': 'Supino',
        'muscle_group': 'chest',
        'sets': 4,
        'reps': 10,
        'weight_kg': 30.0,
      });
    });

    test('grupo muscular desconhecido vira "Outro"', () {
      final exercicio = Exercicio.fromJson({'name': 'X', 'muscle_group': 'novo', 'sets': 1});
      expect(exercicio.grupoMuscular, GrupoMuscular.outro);
    });
  });

  test('SessaoTreino.fromJson lê sessões em andamento e finalizadas', () {
    final ativa = SessaoTreino.fromJson({
      'id': 1,
      'workout_id': 7,
      'workout_name': 'Treino A',
      'workout_type': 'strength',
      'started_at': '2026-11-08T12:00:00Z',
      'finished_at': null,
      'duration_seconds': 0,
      'total_volume_kg': 0,
      'total_sets': 0,
      'last_muscle_group': null,
    });
    expect(ativa.emAndamento, isTrue);
    expect(ativa.ultimoGrupoMuscular, isNull);

    final finalizada = SessaoTreino.fromJson({
      'id': 2,
      'workout_id': null,
      'workout_name': 'Pernas',
      'workout_type': 'strength',
      'started_at': '2026-11-08T12:00:00Z',
      'finished_at': '2026-11-08T13:00:00Z',
      'duration_seconds': 3600,
      'total_volume_kg': 4250.5,
      'total_sets': 18,
      'last_muscle_group': 'calves',
    });
    expect(finalizada.emAndamento, isFalse);
    expect(finalizada.volumeTotalKg, 4250.5);
    expect(finalizada.ultimoGrupoMuscular, GrupoMuscular.panturrilha);
  });

  test('VisaoGeral.fromJson lê semana, sequência e mapa', () {
    final visao = VisaoGeral.fromJson({
      'week': {
        'start': '2026-11-02',
        'end': '2026-11-08',
        'total_sessions': 3,
        'total_duration_seconds': 5400,
        'total_volume_kg': 9000.0,
        'total_sets': 40,
        'days': [
          {'date': '2026-11-02', 'sessions': 1, 'duration_seconds': 1800, 'volume_kg': 3000.0, 'sets': 12},
        ],
      },
      'streak': {'current': 4, 'best': 9, 'trained_today': true},
      'heatmap': {
        'start': '2025-11-10',
        'end': '2026-11-08',
        'days': [
          {'date': '2026-11-02', 'count': 1},
          {'date': '2026-11-08', 'count': 4},
        ],
      },
    });

    expect(visao.semana.inicio, DateTime(2026, 11, 2));
    expect(visao.semana.totalVolumeKg, 9000);
    expect(visao.sequencia.atual, 4);
    expect(visao.mapa.contagem(DateTime(2026, 11, 8, 15, 30)), 4);
    expect(visao.mapa.contagem(DateTime(2026, 11, 3)), 0);
    expect(visao.mapa.totalAtividades, 5);
  });

  test('Pagina.fromJson lê metadados de paginação', () {
    final pagina = Pagina.fromJson(
      {'items': [], 'total': 42, 'offset': 20, 'limit': 20, 'has_more': true},
      Treino.fromJson,
    );
    expect(pagina.total, 42);
    expect(pagina.temMais, isTrue);
  });

  group('Formatadores', () {
    test('cronômetro', () {
      expect(formatarCronometro(const Duration(seconds: 65)), '01:05');
      expect(formatarCronometro(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(formatarCronometro(const Duration(seconds: -5)), '00:00');
    });

    test('volume com separador de milhar', () {
      expect(formatarVolume(850), '850 kg');
      expect(formatarVolume(12480.4), '12.480 kg');
      expect(formatarVolume(1250000), '1.250.000 kg');
    });

    test('duração em segundos', () {
      expect(formatarDuracaoSegundos(45), '45s');
      expect(formatarDuracaoSegundos(3900), '1h 5min');
      expect(formatarDuracaoSegundos(0), '0min');
    });
  });

  test('Validação de e-mail e senha do cadastro', () {
    expect(validarEmail('diego@gmail.com'), isNull);
    expect(validarEmail(' diego@gmail.com '), isNull);
    expect(validarEmail('diego@gmail'), isNotNull);
    expect(validarEmail('diego gmail.com'), isNotNull);
    expect(validarEmail(''), isNotNull);
    expect(validarSenhaNova('1234567'), isNotNull);
    expect(validarSenhaNova('12345678'), isNull);
  });

  testWidgets('Login valida campos obrigatórios e leva ao cadastro', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Campo obrigatório'), findsNWidgets(2));

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.byType(CadastroScreen), findsOneWidget);
  });

  testWidgets('Cadastro valida nome, e-mail e confirmação de senha', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CadastroScreen()));

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Diêgo');
    await tester.enterText(campos.at(1), 'email-invalido');
    await tester.enterText(campos.at(2), 'senha-forte-123');
    await tester.enterText(campos.at(3), 'outra-senha');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pump();

    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(find.text('As senhas não conferem'), findsOneWidget);
  });

  testWidgets('Mapa de atividades usa as cores por quantidade e avisa o dia tocado', (tester) async {
    final hoje = DateTime(2026, 11, 8);
    final mapa = MapaDeAtividades(
      inicio: DateTime(2026, 10, 1),
      fim: hoje,
      contagemPorDia: {
        DateTime(2026, 11, 2): 1,
        DateTime(2026, 11, 3): 2,
        DateTime(2026, 11, 4): 3,
        hoje: 5,
      },
    );
    DateTime? tocado;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(body: MapaAtividades(mapa: mapa, onTapDia: (d) => tocado = d)),
    ));

    Color corDoDia(DateTime dia) {
      final celula = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message!.startsWith(formatarDiaExtenso(dia)),
      );
      final container = tester.widget<Container>(find.descendant(of: celula, matching: find.byType(Container)));
      return (container.decoration! as BoxDecoration).color!;
    }

    final contexto = tester.element(find.byType(MapaAtividades));
    expect(corDoDia(DateTime(2026, 11, 2)), CoresAtividade.paraContagem(contexto, 1));
    expect(corDoDia(DateTime(2026, 11, 2)), const Color(0xFFBFDBFE)); // azul fraco
    expect(corDoDia(DateTime(2026, 11, 3)), const Color(0xFF60A5FA)); // azul médio
    expect(corDoDia(DateTime(2026, 11, 4)), const Color(0xFF1D4ED8)); // azul intenso
    expect(corDoDia(hoje), const Color(0xFF6D3FD9)); // roxo azulado (4 ou mais)

    final celulaHoje = find.byWidgetPredicate((w) => w is Tooltip && w.message!.startsWith(formatarDiaExtenso(hoje)));
    await tester.tap(celulaHoje);
    expect(tocado, hoje);
  });
}
