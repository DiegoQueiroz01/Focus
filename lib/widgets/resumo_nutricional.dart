import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cores fixas de cada macronutriente (iguais em qualquer cor de destaque, para o
/// usuário reconhecer de relance).
abstract final class CoresMacros {
  static const proteina = Color(0xFFEF4444);
  static const carboidrato = Color(0xFFF59E0B);
  static const gordura = Color(0xFF8B5CF6);
}

String _decimal(double v, int casas) => v.toStringAsFixed(casas).replaceAll('.', ',');

/// "150 g", "12,5 g".
String formatarGramas(double gramas) {
  final inteiro = gramas == gramas.roundToDouble() || gramas >= 100;
  return '${inteiro ? gramas.round() : _decimal(gramas, 1)} g';
}

/// "82,4 kg".
String formatarPeso(double kg) => '${_decimal(kg, 1)} kg';

/// "1.850" com separador de milhar.
String formatarKcal(num kcal) {
  final texto = kcal.round().abs().toString();
  final partes = <String>[];
  for (var fim = texto.length; fim > 0; fim -= 3) {
    partes.insert(0, texto.substring(math.max(0, fim - 3), fim));
  }
  return '${kcal < 0 ? '-' : ''}${partes.join('.')}';
}

/// Anel com o progresso das calorias do dia e o quanto ainda falta no centro.
class AnelCalorias extends StatelessWidget {
  final double consumido;
  final int meta;
  final double tamanho;

  const AnelCalorias({super.key, required this.consumido, required this.meta, this.tamanho = 150});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final restante = meta - consumido;
    final passou = restante < 0;
    final progresso = meta <= 0 ? 0.0 : consumido / meta;

    return Semantics(
      label: passou
          ? '${formatarKcal(-restante)} quilocalorias acima da meta'
          : '${formatarKcal(restante)} quilocalorias restantes',
      child: SizedBox.square(
        dimension: tamanho,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progresso),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, valor, _) => CustomPaint(
            painter: _PintorAnel(
              progresso: valor,
              trilho: esquema.surfaceContainer,
              cor: esquema.primary,
              excesso: esquema.error,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatarKcal(restante.abs()),
                    style: tema.textTheme.headlineMedium?.copyWith(
                      color: passou ? esquema.error : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    passou ? 'kcal acima' : 'kcal restantes',
                    style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorAnel extends CustomPainter {
  final double progresso;
  final Color trilho;
  final Color cor;
  final Color excesso;

  _PintorAnel({required this.progresso, required this.trilho, required this.cor, required this.excesso});

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 14.0;
    final rect = Offset.zero & size;
    final arco = rect.deflate(espessura / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arco, 0, math.pi * 2, false, pincel..color = trilho);
    final ate = progresso.clamp(0.0, 1.0);
    if (ate > 0) {
      canvas.drawArc(arco, -math.pi / 2, math.pi * 2 * ate, false, pincel..color = cor);
    }
    // O que passou da meta aparece por cima, na cor de erro.
    if (progresso > 1) {
      final extra = (progresso - 1).clamp(0.0, 1.0);
      canvas.drawArc(arco, -math.pi / 2, math.pi * 2 * extra, false, pincel..color = excesso);
    }
  }

  @override
  bool shouldRepaint(_PintorAnel antigo) =>
      antigo.progresso != progresso || antigo.cor != cor || antigo.trilho != trilho;
}

/// Barra de um macronutriente: "Proteína  92 / 160 g".
class BarraMacro extends StatelessWidget {
  final String nome;
  final double consumido;
  final int meta;
  final Color cor;

  const BarraMacro({super.key, required this.nome, required this.consumido, required this.meta, required this.cor});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final progresso = meta <= 0 ? 0.0 : consumido / meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nome, style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progresso.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => LinearProgressIndicator(
              value: valor,
              minHeight: 8,
              color: progresso > 1.1 ? esquema.error : cor,
              backgroundColor: cor.withValues(alpha: 0.16),
            ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${consumido.round()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' / $meta g', style: TextStyle(color: esquema.onSurfaceVariant)),
              ],
            ),
            style: tema.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

/// Linha "P 12 g · C 30 g · G 5 g" com as cores dos macros.
class LinhaMacros extends StatelessWidget {
  final double proteina;
  final double carboidrato;
  final double gordura;

  const LinhaMacros({super.key, required this.proteina, required this.carboidrato, required this.gordura});

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    Widget item(String letra, double valor, Color cor) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('$letra ${formatarGramas(valor)}', style: estilo),
          ],
        );
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        item('P', proteina, CoresMacros.proteina),
        item('C', carboidrato, CoresMacros.carboidrato),
        item('G', gordura, CoresMacros.gordura),
      ],
    );
  }
}
