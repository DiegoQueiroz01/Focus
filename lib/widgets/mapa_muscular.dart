import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/catalogo_exercicio.dart';
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
///
/// Dois modos: [principais]/[secundarios] (detalhe de um exercício) ou [intensidades]
/// (séries por músculo de uma sessão ou semana: quanto mais séries, mais forte a cor).
class MapaMuscular extends StatelessWidget {
  final Set<String> principais;
  final Set<String> secundarios;
  final Map<String, double> intensidades;

  const MapaMuscular({
    super.key,
    this.principais = const {},
    this.secundarios = const {},
    this.intensidades = const {},
  });

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
          intensidades: intensidades,
          corPrincipal: esquema.primary,
          corSecundaria: CoresMusculos.suave(esquema),
          corBase: esquema.surfaceContainerHighest,
          corContorno: esquema.outline,
        ),
      ),
    );
  }
}

/// Escala de cor usada no desenho e nas legendas: do suave (pouco) ao forte (muito).
class CoresMusculos {
  CoresMusculos._();

  static Color suave(ColorScheme esquema) => esquema.primary.withValues(alpha: 0.3);

  /// [t] de 0 (pouco treinado) a 1 (mais treinado).
  static Color escala(ColorScheme esquema, double t) => Color.lerp(suave(esquema), esquema.primary, t.clamp(0, 1))!;
}

class _PintorCorpo extends CustomPainter {
  final _Desenho desenho;
  final Set<String> principais;
  final Set<String> secundarios;
  final Map<String, double> intensidades;
  final Color corPrincipal;
  final Color corSecundaria;
  final Color corBase;
  final Color corContorno;

  _PintorCorpo({
    required this.desenho,
    required this.principais,
    required this.secundarios,
    required this.intensidades,
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
    final maiorIntensidade = intensidades.values.fold(0.0, (a, b) => a > b ? a : b);

    for (final regiao in desenho.regioes) {
      if (regiao.musculo == 'contorno') {
        canvas.drawPath(regiao.caminho, contorno);
        continue;
      }
      final intensidade = intensidades[regiao.musculo] ?? 0;
      final Color cor;
      if (intensidade > 0 && maiorIntensidade > 0) {
        cor = Color.lerp(corSecundaria, corPrincipal, intensidade / maiorIntensidade)!;
      } else if (principais.contains(regiao.musculo)) {
        cor = corPrincipal;
      } else if (secundarios.contains(regiao.musculo)) {
        cor = corSecundaria;
      } else {
        cor = corBase;
      }
      canvas
        ..drawPath(regiao.caminho, Paint()..color = cor)
        ..drawPath(regiao.caminho, contorno);
    }
  }

  @override
  bool shouldRepaint(_PintorCorpo antigo) =>
      antigo.principais != principais ||
      antigo.secundarios != secundarios ||
      antigo.intensidades != intensidades ||
      antigo.corPrincipal != corPrincipal ||
      antigo.corBase != corBase;
}

/// Desenho do corpo com as séries por músculo, legenda e os músculos mais trabalhados.
class ResumoMuscular extends StatelessWidget {
  final Map<String, double> cargaMuscular;
  final int maximoNaLista;

  const ResumoMuscular({super.key, required this.cargaMuscular, this.maximoNaLista = 5});

  static String _series(double valor) {
    final texto = valor == valor.truncateToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toStringAsFixed(1).replaceAll('.', ',');
    return '$texto ${valor == 1 ? 'série' : 'séries'}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final secundario = esquema.onSurfaceVariant;
    final ranking = cargaMuscular.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maior = ranking.isEmpty ? 1.0 : ranking.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MapaMuscular(intensidades: cargaMuscular),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Menos', style: tema.textTheme.labelSmall?.copyWith(color: secundario)),
            const SizedBox(width: 6),
            for (final t in const [0.0, 0.33, 0.66, 1.0])
              Container(
                width: 18,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: CoresMusculos.escala(esquema, t),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 6),
            Text('Mais', style: tema.textTheme.labelSmall?.copyWith(color: secundario)),
          ],
        ),
        if (ranking.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final MapEntry(:key, :value) in ranking.take(maximoNaLista))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      rotuloMusculo(key),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value / maior,
                        minHeight: 8,
                        backgroundColor: esquema.surfaceContainer,
                        color: CoresMusculos.escala(esquema, value / maior),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _series(value),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.end,
                      style: tema.textTheme.labelMedium?.copyWith(color: secundario),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
