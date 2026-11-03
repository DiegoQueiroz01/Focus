import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/pagina.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/views/login_screen.dart';

void main() {
  group('Treino', () {
    final json = {
      'id': 7,
      'name': 'Treino A',
      'type': 'strength',
      'performed_at': '2026-11-03T14:00:00Z',
      'duration_minutes': 70,
      'total_sets': 8,
      'exercises': [
        {'id': 1, 'name': 'Supino', 'sets': 4, 'reps': 10, 'weight_kg': 30.0},
        {'id': 2, 'name': 'Crucifixo', 'sets': 4, 'reps': 12, 'weight_kg': 14.5},
      ],
    };

    test('fromJson converte o payload da API', () {
      final treino = Treino.fromJson(json);

      expect(treino.id, 7);
      expect(treino.tipo, TipoTreino.musculacao);
      expect(treino.seriesTotais, 8);
      expect(treino.data.isUtc, isFalse);
      expect(treino.exercicios.last.cargaFormatada, '14.5 kg');
      expect(treino.exercicios.first.cargaFormatada, '30 kg');
    });

    test('toJson gera o payload esperado pelo POST /workouts', () {
      final payload = Treino.fromJson(json).toJson();

      expect(payload['name'], 'Treino A');
      expect(payload['type'], 'strength');
      expect(payload['performed_at'], '2026-11-03T14:00:00.000Z');
      expect((payload['exercises'] as List).first, {
        'name': 'Supino',
        'sets': 4,
        'reps': 10,
        'weight_kg': 30.0,
      });
    });

    test('seriesTotais é calculado localmente quando ausente', () {
      final treino = Treino(
        nomeSessao: 'Novo',
        exercicios: const [Exercicio(nome: 'A', series: 3), Exercicio(nome: 'B', series: 2)],
      );
      expect(treino.seriesTotais, 5);
    });
  });

  test('Pagina.fromJson lê metadados de paginação', () {
    final pagina = Pagina.fromJson(
      {'items': [], 'total': 42, 'offset': 20, 'limit': 20, 'has_more': true},
      Treino.fromJson,
    );
    expect(pagina.total, 42);
    expect(pagina.temMais, isTrue);
  });

  testWidgets('Login valida campos obrigatórios', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
  });
}
