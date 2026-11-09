import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/views/dieta_screen.dart';
import 'package:focus/widgets/quantidade_alimento_sheet.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

const _plano = {
  'bmr': 1880,
  'tdee': 2914,
  'calories': 2360,
  'protein_g': 180,
  'carbs_g': 246,
  'fat_g': 66,
  'fiber_g': 33,
  'water_ml': 3150,
  'bmi': 27.8,
  'adjustment_kcal': -554,
  'weekly_change_kg': -0.5,
  'limited_by_minimum': false,
  'custom_calories': false,
  'weeks_to_target': 20,
};

const _arroz = {
  'id': 'taco:3',
  'name': 'Arroz, tipo 1, cozido',
  'category': 'Cereais e derivados',
  'source': 'taco',
  'kcal': 128.0,
  'protein': 2.5,
  'carbs': 28.1,
  'fat': 0.2,
  'fiber': 1.6,
  'portions': [
    {'label': '1 colher de sopa', 'grams': 25},
    {'label': '1 escumadeira', 'grams': 90},
  ],
};

/// API em memória: guarda o perfil e os registros do dia.
class _ApiFalsa extends ApiService {
  Map<String, dynamic>? perfilSalvo;
  final registros = <Map<String, dynamic>>[];

  Map<String, dynamic> _perfilJson() {
    final p = perfilSalvo;
    if (p == null) return {'complete': false};
    return {
      'sex': p['sex'],
      'birth_date': p['birth_date'],
      'age': 30,
      'height_cm': p['height_cm'],
      'activity_level': p['activity_level'],
      'goal': p['goal'],
      'goal_pace': p['goal_pace'],
      'target_weight_kg': p['target_weight_kg'],
      'weight_kg': p['weight_kg'],
      'weight_date': p['weight_date'],
      'complete': true,
      'plan': _plano,
    };
  }

  @override
  Future<PerfilNutricional> getPerfil() async => PerfilNutricional.fromJson(_perfilJson());

  @override
  Future<PerfilNutricional> salvarPerfil(RespostasPerfil respostas) async {
    perfilSalvo = respostas.toJson();
    return PerfilNutricional.fromJson(_perfilJson());
  }

  @override
  Future<DiaDieta> getDiaDieta(DateTime dia) async {
    Map<String, dynamic> totais(Iterable<Map<String, dynamic>> itens) => {
          'kcal': itens.fold<double>(0, (s, e) => s + (e['totals'] as Map)['kcal']),
          'protein': 0,
          'carbs': 0,
          'fat': 0,
          'fiber': 0,
        };
    return DiaDieta.fromJson({
      'date': dataParaApi(dia),
      'plan': perfilSalvo == null ? null : _plano,
      'totals': totais(registros),
      'meals': [
        for (final r in Refeicao.values)
          {
            'meal': r.valorApi,
            'totals': totais(registros.where((e) => e['meal'] == r.valorApi)),
            'entries': registros.where((e) => e['meal'] == r.valorApi).toList(),
          },
      ],
    });
  }

  @override
  Future<List<Alimento>> buscarAlimentos(String? busca, {int limite = 40}) async =>
      (busca ?? '').isEmpty ? [] : [Alimento.fromJson(_arroz)];

  @override
  Future<RegistroAlimento> registrarAlimento({
    required DateTime dia,
    required Refeicao refeicao,
    required String alimentoId,
    required double gramas,
    String? rotuloPorcao,
  }) async {
    final json = {
      'id': registros.length + 1,
      'date': dataParaApi(dia),
      'meal': refeicao.valorApi,
      'food_id': alimentoId,
      'name': _arroz['name'],
      'grams': gramas,
      'portion_label': rotuloPorcao,
      'totals': {'kcal': 128 * gramas / 100, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    };
    registros.add(json);
    return RegistroAlimento.fromJson(json);
  }
}

void main() {
  group('Modelos da dieta', () {
    test('alimento calcula nutrientes pela quantidade', () {
      final arroz = Alimento.fromJson(_arroz);
      expect(arroz.porcoes.first.rotulo, '1 colher de sopa');
      expect(arroz.para(250).kcal, closeTo(320, 0.01));
    });

    test('respostas do perfil omitem o peso quando não informado', () {
      final respostas = RespostasPerfil(
        sexo: Sexo.feminino,
        nascimento: DateTime(1995, 3, 9),
        alturaCm: 165,
        atividade: NivelAtividade.leve,
        objetivo: Objetivo.manter,
        ritmo: Ritmo.rapido,
      );
      final json = respostas.toJson();
      expect(json['birth_date'], '1995-03-09');
      expect(json['goal_pace'], isNull);
      expect(json.containsKey('weight_kg'), isFalse);
    });

    test('refeição sugerida pelo horário', () {
      expect(Refeicao.peloHorario(DateTime(2026, 1, 1, 7)), Refeicao.cafeDaManha);
      expect(Refeicao.peloHorario(DateTime(2026, 1, 1, 12)), Refeicao.almoco);
      expect(Refeicao.peloHorario(DateTime(2026, 1, 1, 20)), Refeicao.jantar);
    });

    test('formatação', () {
      expect(formatarKcal(1850), '1.850');
      expect(formatarGramas(12.5), '12,5 g');
      expect(formatarPeso(82.44), '82,4 kg');
      expect(rotuloPorcoes(const Porcao('1 colher de sopa', 25), 2), '2 × colher de sopa');
    });
  });

  testWidgets('primeiro acesso: questionário, meta e registro de um alimento', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiFalsa();
    ApiService.instance = api;

    await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const DietaScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Vamos montar sua meta'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    // Sexo
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Escolha uma opção.'), findsOneWidget);
    await tester.tap(find.text('Masculino'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Nascimento (com máscara)
    await tester.enterText(find.byType(TextField), '01011995');
    await tester.pump();
    expect(find.text('01/01/1995'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Medidas
    await tester.enterText(find.widgetWithText(TextField, 'Altura'), '180');
    await tester.enterText(find.widgetWithText(TextField, 'Peso atual'), '90,5');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Atividade e objetivo
    await tester.tap(find.text('Moderadamente ativo'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emagrecer'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Ritmo + peso desejado inválido (maior que o atual)
    await tester.enterText(find.widgetWithText(TextField, 'Peso desejado (opcional)'), '95');
    await tester.tap(find.text('Calcular minha meta'));
    await tester.pump();
    expect(find.textContaining('menor que o atual'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Peso desejado (opcional)'), '80');
    await tester.tap(find.text('Calcular minha meta'));
    await tester.pumpAndSettle();

    expect(api.perfilSalvo!['weight_kg'], 90.5);
    expect(api.perfilSalvo!['goal'], 'lose');
    expect(api.perfilSalvo!['goal_pace'], 'moderate');
    expect(api.perfilSalvo!['target_weight_kg'], 80);

    // Tela da meta
    expect(find.text('Minha meta'), findsOneWidget);
    expect(find.text('2.360'), findsOneWidget);
    expect(find.text('~20 semanas'), findsOneWidget);
    await tester.tap(find.text('Começar a registrar'));
    await tester.pumpAndSettle();

    // Diário do dia
    expect(find.text('Café da manhã'), findsOneWidget);
    expect(find.text('2.360 kcal'), findsOneWidget);
    expect(find.text('90,5 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Adicionar ao almoço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arroz, tipo 1, cozido'));
    await tester.pumpAndSettle();

    // 2 escumadeiras = 180 g = 230 kcal
    await tester.tap(find.text('escumadeira (90 g)'));
    await tester.pump();
    await tester.tap(find.byTooltip('Mais'));
    await tester.tap(find.byTooltip('Mais'));
    await tester.pump();
    expect(find.text('230'), findsOneWidget);
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(api.registros.single['grams'], 180);
    expect(api.registros.single['portion_label'], '2 × escumadeira');
    expect(api.registros.single['meal'], 'lunch');

    await tester.tap(find.textContaining('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('2 × escumadeira · 180 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diário, meta e peso cabem num celular pequeno no tema escuro', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiFalsa()
      ..perfilSalvo = RespostasPerfil(
        sexo: Sexo.feminino,
        nascimento: DateTime(1995, 3, 9),
        alturaCm: 165,
        pesoKg: 68.4,
        atividade: NivelAtividade.atleta,
        objetivo: Objetivo.ganhar,
        ritmo: Ritmo.lento,
        pesoMetaKg: 72,
      ).toJson();
    await api.registrarAlimento(dia: DateTime.now(), refeicao: Refeicao.cafeDaManha, alimentoId: 'taco:3', gramas: 2500);
    ApiService.instance = api;

    await tester.pumpWidget(MaterialApp(theme: AppTheme.escuro, home: const DietaScreen()));
    await tester.pumpAndSettle();
    expect(find.text('kcal acima'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Minha meta'));
    await tester.pumpAndSettle();
    expect(find.text('Ganhar massa'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
