import 'package:flutter/material.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/treino_tile.dart';

class TreinoDetalhesScreen extends StatelessWidget {
  final Treino treino;

  const TreinoDetalhesScreen({super.key, required this.treino});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Align(alignment: Alignment.centerLeft, child: IconeTreino(treino: treino, tamanho: 52)),
          const SizedBox(height: 16),
          Text(treino.nomeSessao, style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${treino.tipo.rotulo}  ·  ${treino.dataFormatada}',
            style: tema.textTheme.bodyMedium?.copyWith(color: secundario),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _Estatistica(rotulo: 'Duração', valor: formatarDuracao(treino.tempoTotalMinutos)),
                    const VerticalDivider(),
                    _Estatistica(rotulo: 'Exercícios', valor: '${treino.exercicios.length}'),
                    const VerticalDivider(),
                    _Estatistica(rotulo: 'Séries', valor: '${treino.seriesTotais}'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'EXERCÍCIOS',
            style: tema.textTheme.labelMedium?.copyWith(
              color: secundario,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (treino.exercicios.isEmpty)
            const EstadoVazio(
              icone: Icons.list_alt_rounded,
              titulo: 'Sem exercícios',
              mensagem: 'Nenhum exercício foi registrado nesta sessão.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (indice, ex) in treino.exercicios.indexed) ...[
                    if (indice > 0) const Divider(indent: 64),
                    _LinhaExercicio(numero: indice + 1, exercicio: ex),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Estatistica extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _Estatistica({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: tema.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LinhaExercicio extends StatelessWidget {
  final int numero;
  final Exercicio exercicio;

  const _LinhaExercicio({required this.numero, required this.exercicio});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    final volume = [
      exercicio.repeticoes > 0 ? '${exercicio.series} × ${exercicio.repeticoes}' : '${exercicio.series} séries',
      if (exercicio.cargaKg > 0) exercicio.cargaFormatada,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: esquema.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$numero', style: tema.textTheme.labelLarge),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(exercicio.nome, style: tema.textTheme.titleSmall)),
          Text(volume, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        ],
      ),
    );
  }
}
