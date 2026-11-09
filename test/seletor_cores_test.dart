import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/service/tema_controller.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/theme/cor_destaque.dart';
import 'package:focus/widgets/seletor_cores.dart';

void main() {
  testWidgets('Seletor de cores troca a cor do app', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = TemaController.instance;
    await tester.pumpWidget(ListenableBuilder(
      listenable: controller,
      builder: (_, _) => MaterialApp(
        theme: AppTheme.construir(Brightness.dark, controller.cor),
        home: const Scaffold(body: SeletorCores()),
      ),
    ));

    expect(find.text('Cores do app'), findsOneWidget);
    await tester.tap(find.text('Azul'));
    await tester.pumpAndSettle();
    expect(controller.cor, CorDestaque.azul);

    final contexto = tester.element(find.byType(SeletorCores));
    expect(Theme.of(contexto).colorScheme.primary, CorDestaque.azul.escuro);
    expect(tester.takeException(), isNull);
  });
}
