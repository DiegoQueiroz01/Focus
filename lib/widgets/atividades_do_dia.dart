import 'package:flutter/material.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/sessao_tile.dart';

/// Abre a lista de atividades de um dia em uma folha que sobe da parte de baixo.
Future<void> mostrarAtividadesDoDia(BuildContext context, DateTime dia) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AtividadesDoDia(dia: dia),
  );
}

class _AtividadesDoDia extends StatefulWidget {
  final DateTime dia;

  const _AtividadesDoDia({required this.dia});

  @override
  State<_AtividadesDoDia> createState() => _AtividadesDoDiaState();
}

class _AtividadesDoDiaState extends State<_AtividadesDoDia> {
  late Future<List<SessaoTreino>> _sessoes = ApiService.instance.getSessoesDoDia(widget.dia);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: FutureBuilder<List<SessaoTreino>>(
          future: _sessoes,
          builder: (context, snapshot) {
            final sessoes = snapshot.data ?? const [];
            final finalizadas = sessoes.where((s) => !s.emAndamento);
            final segundos = finalizadas.fold(0, (soma, s) => soma + s.duracaoSegundos);
            final volume = finalizadas.fold(0.0, (soma, s) => soma + s.volumeTotalKg);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatarDiaExtenso(widget.dia), style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                if (snapshot.hasData)
                  Text(
                    sessoes.isEmpty
                        ? 'Nenhuma atividade'
                        : [
                            '${sessoes.length} ${sessoes.length == 1 ? 'atividade' : 'atividades'}',
                            if (segundos > 0) formatarDuracaoSegundos(segundos),
                            if (volume > 0) formatarVolume(volume),
                          ].join('  ·  '),
                    style: tema.textTheme.bodyMedium?.copyWith(color: secundario),
                  ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  EstadoVazio(
                    icone: Icons.cloud_off_rounded,
                    titulo: 'Não foi possível carregar',
                    mensagem: snapshot.error.toString(),
                    rotuloAcao: 'Tentar novamente',
                    onAcao: () => setState(() {
                      _sessoes = ApiService.instance.getSessoesDoDia(widget.dia);
                    }),
                  )
                else if (sessoes.isEmpty)
                  const EstadoVazio(
                    icone: Icons.event_busy_rounded,
                    titulo: 'Dia de descanso',
                    mensagem: 'Você não iniciou nenhum treino neste dia.',
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sessoes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => SessaoTile(sessao: sessoes[i], mostrarData: false),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
