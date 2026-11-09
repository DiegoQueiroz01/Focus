import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focus/models/dieta.dart';

/// Linha simples com a evolução do peso (mais antigo à esquerda) e, se houver,
/// uma linha tracejada no peso desejado.
class GraficoPeso extends StatelessWidget {
  final List<RegistroPeso> registros;
  final double? meta;
  final double altura;

  const GraficoPeso({super.key, required this.registros, this.meta, this.altura = 120});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final ordenados = [...registros]..sort((a, b) => a.data.compareTo(b.data));
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorPeso(
          registros: ordenados,
          meta: meta,
          cor: esquema.primary,
          grade: esquema.outlineVariant,
          texto: esquema.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PintorPeso extends CustomPainter {
  final List<RegistroPeso> registros;
  final double? meta;
  final Color cor;
  final Color grade;
  final Color texto;

  _PintorPeso({required this.registros, this.meta, required this.cor, required this.grade, required this.texto});

  @override
  void paint(Canvas canvas, Size size) {
    if (registros.isEmpty) return;
    final valores = [for (final r in registros) r.pesoKg, ?meta];
    var minimo = valores.reduce(math.min);
    var maximo = valores.reduce(math.max);
    if (maximo - minimo < 2) {
      final meio = (maximo + minimo) / 2;
      minimo = meio - 1;
      maximo = meio + 1;
    }
    const margemY = 12.0;
    const margemDireita = 40.0;
    final largura = size.width - margemDireita;
    final alturaUtil = size.height - margemY * 2;
    double y(double kg) => margemY + (maximo - kg) / (maximo - minimo) * alturaUtil;

    final inicio = registros.first.data;
    final dias = math.max(1, registros.last.data.difference(inicio).inDays);
    double x(DateTime d) => registros.length == 1 ? largura / 2 : d.difference(inicio).inDays / dias * largura;

    void rotulo(double kg) {
      final pintor = TextPainter(
        text: TextSpan(
          text: kg.toStringAsFixed(1).replaceAll('.', ','),
          style: TextStyle(color: texto, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pintor.paint(canvas, Offset(largura + 6, y(kg) - pintor.height / 2));
    }

    final linhaGrade = Paint()
      ..color = grade
      ..strokeWidth = 1;
    for (final kg in [maximo, minimo]) {
      canvas.drawLine(Offset(0, y(kg)), Offset(largura, y(kg)), linhaGrade);
      rotulo(kg);
    }

    if (meta != null) {
      final tracejado = Paint()
        ..color = cor.withValues(alpha: 0.5)
        ..strokeWidth = 1.5;
      for (double px = 0; px < largura; px += 8) {
        canvas.drawLine(Offset(px, y(meta!)), Offset(math.min(px + 4, largura), y(meta!)), tracejado);
      }
    }

    final caminho = Path();
    for (final (i, r) in registros.indexed) {
      final ponto = Offset(x(r.data), y(r.pesoKg));
      i == 0 ? caminho.moveTo(ponto.dx, ponto.dy) : caminho.lineTo(ponto.dx, ponto.dy);
    }
    final area = Path.from(caminho)
      ..lineTo(x(registros.last.data), size.height)
      ..lineTo(x(registros.first.data), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cor.withValues(alpha: 0.22), cor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      caminho,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final ultimo = registros.last;
    canvas.drawCircle(Offset(x(ultimo.data), y(ultimo.pesoKg)), 4.5, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_PintorPeso antigo) =>
      antigo.registros != registros || antigo.meta != meta || antigo.cor != cor;
}
