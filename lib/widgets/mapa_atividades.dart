import 'package:flutter/material.dart';
import 'package:focus/models/visao_geral.dart';
import 'package:focus/utils/formatadores.dart';

/// Cores do mapa por quantidade de atividades no dia.
class CoresAtividade {
  CoresAtividade._();

  // Claro: o azul fica mais escuro conforme aumenta. Escuro: fica mais brilhante.
  static const _claro = [Color(0xFFBFDBFE), Color(0xFF60A5FA), Color(0xFF1D4ED8), Color(0xFF6D3FD9)];
  static const _escuro = [Color(0xFF1E3A5F), Color(0xFF2563EB), Color(0xFF60A5FA), Color(0xFF8B6CF6)];

  /// 1 = azul fraco, 2 = azul médio, 3 = azul intenso, 4+ = roxo azulado.
  static Color paraContagem(BuildContext context, int contagem) {
    final esquema = Theme.of(context).colorScheme;
    if (contagem <= 0) return esquema.surfaceContainer;
    final cores = Theme.of(context).brightness == Brightness.dark ? _escuro : _claro;
    return cores[(contagem.clamp(1, 4)) - 1];
  }
}

/// Grade de dias com atividade, no estilo do gráfico de contribuições do GitHub.
/// Cada coluna é uma semana (domingo no topo); a rolagem começa nas semanas mais recentes.
class MapaAtividades extends StatelessWidget {
  final MapaDeAtividades mapa;
  final DateTime? diaSelecionado;
  final ValueChanged<DateTime> onTapDia;

  const MapaAtividades({super.key, required this.mapa, required this.onTapDia, this.diaSelecionado});

  static const double _celula = 14;
  static const double _espaco = 3;
  static const double _passo = _celula + _espaco;
  static const double _alturaMeses = 18;
  static const double _larguraDiasSemana = 30;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    final estiloRotulo = tema.textTheme.labelSmall?.copyWith(color: secundario, fontSize: 10);

    final fim = inicioDoDia(mapa.fim);
    // Primeira coluna começa no domingo da semana do primeiro dia.
    final primeiroDomingo = DateTime(mapa.inicio.year, mapa.inicio.month, mapa.inicio.day - mapa.inicio.weekday % 7);
    final semanas = (fim.difference(primeiroDomingo).inDays ~/ 7) + 1;

    final colunas = <Widget>[];
    // (coluna, mês): o rótulo aparece na coluna em que o mês muda.
    final mudancasDeMes = <(int, int)>[];

    for (var s = 0; s < semanas; s++) {
      final domingo = DateTime(primeiroDomingo.year, primeiroDomingo.month, primeiroDomingo.day + s * 7);
      final mes = domingo.month;
      if (mudancasDeMes.isEmpty || mudancasDeMes.last.$2 != mes) mudancasDeMes.add((s, mes));

      colunas.add(Column(
        children: [
          for (var d = 0; d < 7; d++)
            _celulaDoDia(context, DateTime(domingo.year, domingo.month, domingo.day + d), fim),
        ],
      ));
    }

    final rotulosMeses = <Widget>[
      for (final (i, (coluna, mes)) in mudancasDeMes.indexed)
        // Pula um rótulo que ficaria colado no próximo (ex.: primeira coluna no fim do mês).
        if (i == mudancasDeMes.length - 1 || mudancasDeMes[i + 1].$1 - coluna >= 3)
          Positioned(left: coluna * _passo, child: Text(nomeDoMesCurto(mes), style: estiloRotulo)),
    ];
    final larguraGrade = semanas * _passo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _larguraDiasSemana,
              child: Padding(
                padding: const EdgeInsets.only(top: _alturaMeses),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final rotulo in const ['', 'Seg', '', 'Qua', '', 'Sex', ''])
                      SizedBox(
                        height: _passo,
                        child: Align(alignment: Alignment.centerLeft, child: Text(rotulo, style: estiloRotulo)),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: larguraGrade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: _alturaMeses, width: larguraGrade, child: Stack(children: rotulosMeses)),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: colunas),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${mapa.totalAtividades} ${mapa.totalAtividades == 1 ? 'atividade' : 'atividades'} no último ano',
                style: tema.textTheme.bodySmall?.copyWith(color: secundario),
              ),
            ),
            Text('Menos', style: estiloRotulo),
            const SizedBox(width: 4),
            for (var c = 0; c <= 4; c++)
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: CoresAtividade.paraContagem(context, c),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 4),
            Text('Mais', style: estiloRotulo),
          ],
        ),
      ],
    );
  }

  Widget _celulaDoDia(BuildContext context, DateTime dia, DateTime fim) {
    final foraDoPeriodo = dia.isAfter(fim) || dia.isBefore(inicioDoDia(mapa.inicio));
    if (foraDoPeriodo) return const SizedBox(width: _passo, height: _passo);

    final contagem = mapa.contagem(dia);
    final selecionado = diaSelecionado != null && inicioDoDia(diaSelecionado!) == dia;
    final hoje = dia == fim;
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: _espaco, bottom: _espaco),
      child: Tooltip(
        message: '${formatarDiaExtenso(dia)}: '
            '${contagem == 0 ? 'nenhuma atividade' : '$contagem ${contagem == 1 ? 'atividade' : 'atividades'}'}',
        child: GestureDetector(
          onTap: () => onTapDia(dia),
          child: Container(
            width: _celula,
            height: _celula,
            decoration: BoxDecoration(
              color: CoresAtividade.paraContagem(context, contagem),
              borderRadius: BorderRadius.circular(3),
              border: selecionado
                  ? Border.all(color: esquema.onSurface, width: 1.5)
                  : hoje
                      ? Border.all(color: esquema.onSurfaceVariant.withValues(alpha: 0.6))
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
