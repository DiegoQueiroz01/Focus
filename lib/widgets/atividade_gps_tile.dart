import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/gps_resumo_screen.dart';
import 'package:focus/widgets/metrica_gps.dart';

/// Cor de destaque das atividades por GPS nas listas (azul, para diferenciar dos treinos).
const corAtividadeGps = Color(0xFF0EA5E9);

/// Abre o resumo de uma atividade já salva (mapa, parciais, comentário).
Future<void> abrirAtividadeGps(BuildContext context, AtividadeGps atividade) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => GpsResumoScreen.salva(id: atividade.id!, previa: atividade)),
  );
}

/// Linha do histórico para uma atividade gravada pelo GPS, no mesmo formato do [SessaoTile].
class AtividadeGpsTile extends StatelessWidget {
  final AtividadeGps atividade;
  final bool mostrarData;
  final VoidCallback? onTap;

  const AtividadeGpsTile({super.key, required this.atividade, this.mostrarData = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    final inicio = atividade.iniciadaEm;
    final ritmo = ritmoOuVelocidade(atividade.tipo, atividade.ritmoMedio);

    final quando = mostrarData ? '${formatarDataRelativa(inicio)}, ${formatarHora(inicio)}' : formatarHora(inicio);
    final detalhes = [
      quando,
      formatarDistancia(atividade.distanciaMetros),
      if (atividade.ritmoMedio != null) ritmo.valor,
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: corAtividadeGps.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(44 * 0.32),
                ),
                child: Icon(atividade.tipo.icone, color: corAtividadeGps, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      atividade.tipo.rotulo,
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
              Text(
                formatarDuracaoSegundos(atividade.tempoMovimentoSegundos),
                style: tema.textTheme.labelLarge?.copyWith(color: secundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
