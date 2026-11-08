import 'package:flutter/material.dart';
import 'package:focus/models/treino_model.dart';

class IconeTreino extends StatelessWidget {
  final TipoTreino tipo;
  final String nome;
  final double tamanho;

  const IconeTreino({super.key, required this.tipo, this.nome = '', this.tamanho = 44});

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (tipo) {
      TipoTreino.musculacao => (Icons.fitness_center_rounded, const Color(0xFF16A34A)),
      TipoTreino.cardio when nome.toLowerCase().contains('bicicleta') =>
        (Icons.directions_bike_rounded, const Color(0xFF0EA5E9)),
      TipoTreino.cardio => (Icons.directions_run_rounded, const Color(0xFFF97316)),
      TipoTreino.outro => (Icons.bolt_rounded, const Color(0xFF8B5CF6)),
    };

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tamanho * 0.32),
      ),
      child: Icon(icone, color: cor, size: tamanho * 0.5),
    );
  }
}

class TreinoTile extends StatelessWidget {
  final Treino treino;
  final VoidCallback? onTap;

  const TreinoTile({super.key, required this.treino, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    final quantidade = treino.exercicios.length;
    final grupos = treino.gruposMusculares.map((g) => g.rotulo);

    final detalhes = [
      quantidade == 0 ? 'Sem exercícios' : '$quantidade ${quantidade == 1 ? 'exercício' : 'exercícios'}',
      if (grupos.isNotEmpty) grupos.take(3).join(', ') + (grupos.length > 3 ? '…' : ''),
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconeTreino(tipo: treino.tipo, nome: treino.nomeSessao),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treino.nomeSessao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalhes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: secundario),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: secundario),
            ],
          ),
        ),
      ),
    );
  }
}
