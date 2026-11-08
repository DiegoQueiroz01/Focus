import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/service/rastreador_gps.dart';
import 'package:focus/views/gps_sessao_screen.dart';

class _ApiFalsa extends ApiService {
  AtividadeGps? salva;

  @override
  Future<AtividadeGps> salvarAtividadeGps(AtividadeGps atividade) async {
    salva = atividade;
    return AtividadeGps.fromJson({...atividade.toJson(), 'id': 1, 'calories': atividade.calorias});
  }
}

class _FonteControlada implements FonteLocalizacao {
  final controlador = StreamController<LeituraGps>();

  @override
  Future<String?> preparar() async => null;

  @override
  Stream<LeituraGps> leituras() => controlador.stream;
}

void main() {
  testWidgets('grava, encerra, comenta e salva a atividade', (tester) async {
    // Tela alta o bastante para o resumo inteiro caber sem rolar.
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiFalsa();
    ApiService.instance = api;
    final fonte = _FonteControlada();
    bool? resultado;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => GpsSessaoScreen(tipo: TipoAtividadeGps.corrida, fonte: fonte),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    fonte.controlador.add(LeituraGps(latitude: -13, longitude: -38.5, horario: DateTime.now()));
    await tester.pump();
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      fonte.controlador.add(LeituraGps(latitude: -13 + i * 0.0001, longitude: -38.5, horario: DateTime.now()));
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text('Pausar'));
    await tester.pump();
    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Resumo da atividade'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Treino leve');
    await tester.tap(find.text('Salvar atividade'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(api.salva?.comentario, 'Treino leve');
    expect(resultado, isTrue);
    expect(find.text('abrir'), findsOneWidget);
  });
}
