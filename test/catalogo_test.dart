import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/catalogo_exercicio.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/pagina.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/views/catalogo_exercicios_screen.dart';
import 'package:focus/widgets/dialogo_padrao.dart';
import 'package:focus/widgets/mapa_muscular.dart';

const _supino = CatalogoExercicio(
  id: 'supino',
  nome: 'Supino reto com barra',
  nomeIngles: 'Barbell Bench Press',
  tipo: TipoTreino.musculacao,
  grupoMuscular: GrupoMuscular.peito,
  musculosPrincipais: ['chest'],
  musculosSecundarios: ['shoulders', 'triceps'],
  equipamento: 'Barra',
  nivel: 'beginner',
  imagensUrl: [],
  instrucoes: ['Lie back on a flat bench.'],
);

const _rosca = CatalogoExercicio(
  id: 'rosca',
  nome: 'Rosca direta com barra',
  tipo: TipoTreino.musculacao,
  grupoMuscular: GrupoMuscular.biceps,
  musculosPrincipais: ['biceps'],
);

const _natacao = CatalogoExercicio(
  id: 'natacao',
  nome: 'Natação',
  tipo: TipoTreino.cardio,
  grupoMuscular: GrupoMuscular.cardio,
  musculosPrincipais: ['lats', 'shoulders'],
  icone: 'pool',
  descricao: 'Nado em piscina.',
);

/// API falsa: filtra uma lista fixa como o backend faria.
class _ApiFalsa extends ApiService {
  final consultas = <(TipoTreino?, GrupoMuscular?, String?)>[];

  @override
  Future<Pagina<CatalogoExercicio>> getCatalogo({
    String? busca,
    TipoTreino? tipo,
    GrupoMuscular? grupo,
    int offset = 0,
    int limite = 30,
  }) async {
    consultas.add((tipo, grupo, busca));
    final itens = [_supino, _rosca, _natacao]
        .where((e) => (tipo == null || e.tipo == tipo) && (grupo == null || e.grupoMuscular == grupo))
        .where((e) => busca == null || busca.isEmpty || e.nome.toLowerCase().contains(busca.toLowerCase()))
        .toList();
    return Pagina(itens: itens, total: itens.length, offset: 0, temMais: false);
  }

  @override
  Future<CatalogoExercicio> getExercicioCatalogo(String id) async =>
      [_supino, _rosca, _natacao].firstWhere((e) => e.id == id);
}

void main() {
  late _ApiFalsa api;

  setUp(() {
    api = _ApiFalsa();
    ApiService.instance = api;
  });

  // O asset do desenho é lido de verdade (fora do relógio falso dos testes).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MapaMuscular.precarregar();
  });

  test('CatalogoExercicio.fromJson lê resumo e detalhe', () {
    final item = CatalogoExercicio.fromJson({
      'id': 'Barbell_Bench_Press_-_Medium_Grip',
      'name': 'Supino reto com barra',
      'name_en': 'Barbell Bench Press - Medium Grip',
      'type': 'strength',
      'muscle_group': 'chest',
      'primary_muscles': ['chest'],
      'secondary_muscles': ['shoulders', 'triceps'],
      'equipment': 'Barra',
      'level': 'beginner',
      'image_url': 'https://cdn/x/0.jpg',
      'icon': null,
      'image_urls': ['https://cdn/x/0.jpg', 'https://cdn/x/1.jpg'],
      'description': null,
      'instructions': ['Passo 1'],
    });
    expect(item.grupoMuscular, GrupoMuscular.peito);
    expect(item.nivelRotulo, 'Iniciante');
    expect(item.resumoMusculos, 'Peito');
    expect(item.imagensUrl, hasLength(2));
    expect(rotuloMusculo('middle back'), 'Meio das costas');
  });

  testWidgets('Mapa muscular pinta os músculos principais e secundários', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: const Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: MapaMuscular(principais: {'chest'}, secundarios: {'triceps'})),
        ),
      ),
    ));
    await tester.pump();

    final pintura = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(MapaMuscular), matching: find.byType(CustomPaint)),
    );
    expect(pintura.painter, isNotNull);
    await expectLater(find.byType(MapaMuscular), matchesGoldenFile('goldens/mapa_muscular.png'));
  });

  testWidgets('Catálogo filtra por tipo e grupo muscular e devolve o exercício escolhido', (tester) async {
    // Tela de celular em pé.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    EscolhaCatalogo? escolha;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => escolha = await Navigator.push<EscolhaCatalogo>(
              context,
              MaterialPageRoute(builder: (_) => const CatalogoExerciciosScreen()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Musculação: mostra os dois exercícios e os filtros por grupo muscular.
    expect(find.text('Supino reto com barra'), findsOneWidget);
    expect(find.text('Rosca direta com barra'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Peito'), findsOneWidget);

    final biceps = find.widgetWithText(ChoiceChip, 'Bíceps', skipOffstage: false);
    await tester.ensureVisible(biceps);
    await tester.pumpAndSettle();
    await tester.tap(biceps);
    await tester.pumpAndSettle();
    expect(api.consultas.last, (TipoTreino.musculacao, GrupoMuscular.biceps, ''));
    expect(find.text('Supino reto com barra'), findsNothing);
    expect(find.text('Rosca direta com barra'), findsOneWidget);

    // Cardio: sem filtro de grupo muscular.
    await tester.tap(find.text('Cardio'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Natação'), findsOneWidget);
    expect(api.consultas.last.$2, isNull);

    // Abre o detalhe, vê os músculos e adiciona ao treino.
    await tester.tap(find.text('Natação'));
    await tester.pumpAndSettle();
    expect(find.text('Nado em piscina.'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Dorsais, Ombros'), 200);
    expect(find.text('MÚSCULOS TRABALHADOS'), findsOneWidget);
    expect(find.byType(MapaMuscular), findsOneWidget);
    await tester.tap(find.text('Adicionar ao treino'));
    await tester.pumpAndSettle();

    expect(escolha, isA<ExercicioEscolhido>());
    expect((escolha! as ExercicioEscolhido).exercicio.id, 'natacao');
  });

  testWidgets('Busca sem resultado oferece criar exercício personalizado', (tester) async {
    EscolhaCatalogo? escolha;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => escolha = await Navigator.push<EscolhaCatalogo>(
            context,
            MaterialPageRoute(builder: (_) => const CatalogoExerciciosScreen()),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Exercício do meu professor');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum exercício encontrado'), findsOneWidget);

    await tester.tap(find.text('Criar "Exercício do meu professor"'));
    await tester.pumpAndSettle();
    expect((escolha! as ExercicioPersonalizado).nome, 'Exercício do meu professor');
  });
  testWidgets('Resumo muscular destaca mais os músculos com mais séries', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.escuro,
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ResumoMuscular(cargaMuscular: {'chest': 8, 'triceps': 4, 'shoulders': 2, 'lats': 1}),
        ),
      ),
    ));
    await tester.pump();

    final rotulos = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(rotulos.indexOf('Peito'), lessThan(rotulos.indexOf('Tríceps')));
    expect(find.text('8 séries'), findsOneWidget);
    await expectLater(find.byType(ResumoMuscular), matchesGoldenFile('goldens/resumo_muscular.png'));
  });

  testWidgets('Diálogo padrão empilha os botões ocupando toda a largura', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmar(
            context,
            titulo: 'Finalizar treino?',
            mensagem: 'Texto',
            rotuloConfirmar: 'Finalizar',
            rotuloCancelar: 'Continuar treinando',
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final principal = tester.getRect(find.widgetWithText(FilledButton, 'Finalizar'));
    final secundario = tester.getRect(find.widgetWithText(TextButton, 'Continuar treinando'));
    expect(principal.width, secundario.width);
    expect(principal.center.dx, secundario.center.dx);
    expect(secundario.top, greaterThan(principal.bottom));
  });
}
