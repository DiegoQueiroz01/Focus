import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

/// Uma região do desenho do corpo (ex.: um dos lados do peitoral).
class _Regiao {
  final String musculo;
  final Path caminho;

  const _Regiao(this.musculo, this.caminho);
}

class _Desenho {
  final List<_Regiao> regioes;
  final Rect limites;

  const _Desenho(this.regioes, this.limites);
}

/// Corpo humano de frente e de costas, com os músculos trabalhados destacados.
/// Os nomes dos músculos seguem o catálogo ("chest", "middle back"...).
class MapaMuscular extends StatelessWidget {
  final Set<String> principais;
  final Set<String> secundarios;

  const MapaMuscular({super.key, required this.principais, this.secundarios = const {}});

  static Future<_Desenho>? _desenho;

  /// Desenho já lido; depois da primeira vez é usado direto, sem esperar.
  static _Desenho? _pronto;

  /// Lê o desenho antes da primeira exibição (evita o indicador de carregamento).
  static Future<void> precarregar() => _carregar();

  static Future<_Desenho> _carregar() {
    return _desenho ??= rootBundle.loadString('assets/corpo/mapa_muscular.json').then((texto) {
      final dados = jsonDecode(texto) as Map<String, dynamic>;
      final regioes = [
        for (final r in dados['regioes'] as List) _Regiao(r['m'] as String, parseSvgPathData(r['d'] as String)),
      ];
      final limites = regioes.map((r) => r.caminho.getBounds()).reduce((a, b) => a.expandToInclude(b));
      return _pronto = _Desenho(regioes, limites);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pronto = _pronto;
    if (pronto != null) return _corpo(context, pronto);

    return FutureBuilder<_Desenho>(
      future: _carregar(),
      builder: (context, snapshot) {
        final desenho = snapshot.data;
        if (desenho == null) {
          return const AspectRatio(aspectRatio: 1.2, child: Center(child: CircularProgressIndicator()));
        }
        return _corpo(context, desenho);
      },
    );
  }

  Widget _corpo(BuildContext context, _Desenho desenho) {
    final esquema = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: desenho.limites.width / desenho.limites.height,
      child: CustomPaint(
        painter: _PintorCorpo(
          desenho: desenho,
          principais: principais,
          secundarios: secundarios,
          corPrincipal: esquema.primary,
          corSecundaria: esquema.primary.withValues(alpha: 0.35),
          corBase: esquema.surfaceContainerHighest,
          corContorno: esquema.outline,
        ),
      ),
    );
  }
}

class _PintorCorpo extends CustomPainter {
  final _Desenho desenho;
  final Set<String> principais;
  final Set<String> secundarios;
  final Color corPrincipal;
  final Color corSecundaria;
  final Color corBase;
  final Color corContorno;

  _PintorCorpo({
    required this.desenho,
    required this.principais,
    required this.secundarios,
    required this.corPrincipal,
    required this.corSecundaria,
    required this.corBase,
    required this.corContorno,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final limites = desenho.limites;
    final escala = size.width / limites.width;
    canvas
      ..scale(escala)
      ..translate(-limites.left, -limites.top);

    final contorno = Paint()
      ..style = PaintingStyle.stroke
      // Espessura fixa na tela, qualquer que seja o tamanho do desenho.
      ..strokeWidth = 0.8 / escala
      ..color = corContorno;

    for (final regiao in desenho.regioes) {
      if (regiao.musculo == 'contorno') {
        canvas.drawPath(regiao.caminho, contorno);
        continue;
      }
      final cor = principais.contains(regiao.musculo)
          ? corPrincipal
          : secundarios.contains(regiao.musculo)
          ? corSecundaria
          : corBase;
      canvas
        ..drawPath(regiao.caminho, Paint()..color = cor)
        ..drawPath(regiao.caminho, contorno);
    }
  }

  @override
  bool shouldRepaint(_PintorCorpo antigo) =>
      antigo.principais != principais ||
      antigo.secundarios != secundarios ||
      antigo.corPrincipal != corPrincipal ||
      antigo.corBase != corBase;
}
