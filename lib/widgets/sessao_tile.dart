import 'package:flutter/material.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/treino_tile.dart';

/// Linha do histórico: uma sessão de treino executada.
class SessaoTile extends StatelessWidget {
  final SessaoTreino sessao;
  final bool mostrarData;
  final VoidCallback? onTap;

  const SessaoTile({super.key, required this.sessao, this.mostrarData = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final secundario = esquema.onSurfaceVariant;

    final quando = mostrarData
        ? '${formatarDataRelativa(sessao.iniciadaEm)}, ${formatarHora(sessao.iniciadaEm)}'
        : formatarHora(sessao.iniciadaEm);
    final detalhes = [
      quando,
      if (sessao.volumeTotalKg > 0) formatarVolume(sessao.volumeTotalKg),
      if (sessao.ultimoGrupoMuscular != null) sessao.ultimoGrupoMuscular!.rotulo,
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconeTreino(tipo: sessao.tipo, nome: sessao.nomeTreino),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessao.nomeTreino,
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
              const SizedBox(width: 12),
              if (sessao.emAndamento)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: esquema.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Em andamento',
                    style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary),
                  ),
                )
              else
                Text(
                  formatarDuracaoSegundos(sessao.duracaoSegundos),
                  style: tema.textTheme.labelLarge?.copyWith(color: secundario),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
