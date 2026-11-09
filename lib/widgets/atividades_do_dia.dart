import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/atividade_gps_tile.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/sessao_tile.dart';

/// Abre a lista de atividades de um dia (treinos e GPS) em uma folha que sobe da parte de baixo.
Future<void> mostrarAtividadesDoDia(BuildContext context, DateTime dia) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AtividadesDoDia(dia: dia),
  );
}

typedef _DoDia = ({List<SessaoTreino> sessoes, List<AtividadeGps> gps});

Future<_DoDia> _buscar(DateTime dia) async {
  final api = ApiService.instance;
  final (sessoes, gps) = await (api.getSessoesDoDia(dia), api.getAtividadesGpsDoDia(dia)).wait;
  return (sessoes: sessoes, gps: gps);
}

class _AtividadesDoDia extends StatefulWidget {
  final DateTime dia;

  const _AtividadesDoDia({required this.dia});

  @override
  State<_AtividadesDoDia> createState() => _AtividadesDoDiaState();
}

class _AtividadesDoDiaState extends State<_AtividadesDoDia> {
  late Future<_DoDia> _dados = _buscar(widget.dia);

  void _recarregar() => setState(() => _dados = _buscar(widget.dia));

  Future<void> _abrirGps(AtividadeGps atividade) async {
    await abrirAtividadeGps(context, atividade);
    // A atividade pode ter sido excluída ou comentada no resumo.
    if (mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: FutureBuilder<_DoDia>(
          future: _dados,
          builder: (context, snapshot) {
            final sessoes = snapshot.data?.sessoes ?? const <SessaoTreino>[];
            final gps = snapshot.data?.gps ?? const <AtividadeGps>[];
            final total = sessoes.length + gps.length;

            final finalizadas = sessoes.where((s) => !s.emAndamento);
            final segundos = finalizadas.fold<int>(0, (soma, s) => soma + s.duracaoSegundos) +
                gps.fold<int>(0, (soma, a) => soma + a.tempoMovimentoSegundos);
            final volume = finalizadas.fold<double>(0, (soma, s) => soma + s.volumeTotalKg);
            final distancia = gps.fold<double>(0, (soma, a) => soma + a.distanciaMetros);

            // Treinos e atividades por GPS juntos, do mais recente para o mais antigo.
            final itens = <(DateTime, Widget)>[
              for (final s in sessoes) (s.iniciadaEm, SessaoTile(sessao: s, mostrarData: false)),
              for (final a in gps)
                (a.iniciadaEm, AtividadeGpsTile(atividade: a, mostrarData: false, onTap: () => _abrirGps(a))),
            ]..sort((a, b) => b.$1.compareTo(a.$1));

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatarDiaExtenso(widget.dia), style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                if (snapshot.hasData)
                  Text(
                    total == 0
                        ? 'Nenhuma atividade'
                        : [
                            '$total ${total == 1 ? 'atividade' : 'atividades'}',
                            if (segundos > 0) formatarDuracaoSegundos(segundos),
                            if (distancia > 0) formatarDistancia(distancia),
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
                    onAcao: _recarregar,
                  )
                else if (itens.isEmpty)
                  const EstadoVazio(
                    icone: Icons.event_busy_rounded,
                    titulo: 'Dia de descanso',
                    mensagem: 'Nenhum treino ou atividade por GPS neste dia.',
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: itens.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => itens[i].$2,
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
