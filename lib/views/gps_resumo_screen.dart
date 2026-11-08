import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/dialogo_padrao.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/mapa_trajeto.dart';
import 'package:focus/widgets/metrica_gps.dart';

/// Resumo de uma atividade por GPS.
/// - [GpsResumoScreen.nova]: logo após encerrar; o usuário comenta e salva (retorna true) ou descarta.
/// - [GpsResumoScreen.salva]: aberta pelo histórico; permite editar o comentário ou excluir.
class GpsResumoScreen extends StatefulWidget {
  final AtividadeGps? atividade;
  final int? id;

  const GpsResumoScreen.nova({super.key, required AtividadeGps this.atividade}) : id = null;

  const GpsResumoScreen.salva({super.key, required int this.id, AtividadeGps? previa}) : atividade = previa;

  bool get nova => id == null;

  @override
  State<GpsResumoScreen> createState() => _GpsResumoScreenState();
}

class _GpsResumoScreenState extends State<GpsResumoScreen> {
  AtividadeGps? _atividade;
  Object? _erroCarregar;
  final _comentario = TextEditingController();
  bool _salvando = false;
  bool _detalheCarregado = false;

  @override
  void initState() {
    super.initState();
    _atividade = widget.atividade;
    _comentario.text = _atividade?.comentario ?? '';
    _comentario.addListener(() => setState(() {}));
    if (!widget.nova) _carregar();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erroCarregar = null);
    try {
      final atividade = await ApiService.instance.getAtividadeGps(widget.id!);
      if (!mounted) return;
      setState(() {
        _atividade = atividade;
        _detalheCarregado = true;
        _comentario.text = atividade.comentario ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _erroCarregar = e);
    }
  }

  String? get _textoComentario => _comentario.text.trim().isEmpty ? null : _comentario.text.trim();

  Future<void> _salvar() async {
    final atividade = _atividade!;
    setState(() => _salvando = true);
    try {
      if (widget.nova) {
        await ApiService.instance.salvarAtividadeGps(atividade.copiarCom(comentario: _textoComentario));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividade salva')));
        Navigator.of(context).pop(true);
      } else {
        final atualizada = await ApiService.instance.atualizarComentarioGps(atividade.id!, _textoComentario);
        if (!mounted) return;
        setState(() => _atividade = atualizada);
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentário salvo')));
      }
    } catch (e) {
      // Os dados continuam na tela, então dá para tentar de novo.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _descartar() async {
    final ok = await confirmar(
      context,
      titulo: 'Descartar atividade?',
      mensagem: 'Ela não será salva no seu histórico.',
      rotuloConfirmar: 'Descartar',
      icone: Icons.delete_outline_rounded,
      destrutivo: true,
    );
    if (ok && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _excluir() async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir atividade?',
      mensagem: 'Ela será removida do seu histórico.',
      rotuloConfirmar: 'Excluir',
      icone: Icons.delete_outline_rounded,
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    try {
      await ApiService.instance.excluirAtividadeGps(_atividade!.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final atividade = _atividade;
    final carregandoDetalhe = !widget.nova && !_detalheCarregado && _erroCarregar == null;

    return PopScope(
      // Uma atividade nova só sai daqui salvando ou descartando.
      canPop: !widget.nova,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _descartar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.nova ? 'Resumo da atividade' : (atividade?.tipo.rotulo ?? 'Atividade')),
          actions: [
            if (!widget.nova && atividade != null)
              IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Excluir', onPressed: _excluir),
          ],
        ),
        body: switch (atividade) {
          null when _erroCarregar != null => EstadoVazio(
              icone: Icons.cloud_off_rounded,
              titulo: 'Não foi possível carregar',
              mensagem: _erroCarregar.toString(),
              rotuloAcao: 'Tentar novamente',
              onAcao: _carregar,
            ),
          null => const Center(child: CircularProgressIndicator()),
          _ => _Conteudo(atividade: atividade, comentario: _comentario, carregandoDetalhe: carregandoDetalhe),
        },
        bottomNavigationBar: atividade == null ? null : _construirBotoes(atividade),
      ),
    );
  }

  Widget? _construirBotoes(AtividadeGps atividade) {
    const altura = Size.fromHeight(52);
    final carregando = const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));

    if (widget.nova) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: altura),
              onPressed: _salvando ? null : _salvar,
              icon: _salvando ? carregando : const Icon(Icons.check_rounded),
              label: const Text('Salvar atividade'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _salvando ? null : _descartar, child: const Text('Descartar')),
          ],
        ),
      );
    }

    if (_textoComentario == atividade.comentario) return null;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: altura),
        onPressed: _salvando ? null : _salvar,
        icon: _salvando ? carregando : const Icon(Icons.check_rounded),
        label: const Text('Salvar comentário'),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  final AtividadeGps atividade;
  final TextEditingController comentario;
  final bool carregandoDetalhe;

  const _Conteudo({required this.atividade, required this.comentario, required this.carregandoDetalhe});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final a = atividade;
    final media = ritmoOuVelocidade(a.tipo, a.ritmoMedio, prefixo: '');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1.3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MapaTrajeto(trajeto: a.trajeto, interativo: true),
                if (carregandoDetalhe) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              backgroundColor: esquema.primary.withValues(alpha: 0.14),
              child: Icon(a.tipo.icone, color: esquema.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.tipo.rotulo, style: tema.textTheme.titleLarge),
                  Text(
                    '${formatarDiaExtenso(a.iniciadaEm)} · ${formatarHora(a.iniciadaEm)}–${formatarHora(a.finalizadaEm)}',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricaGps(rotulo: 'Distância', valor: formatarDistancia(a.distanciaMetros), grande: true),
                    ),
                    Expanded(
                      child: MetricaGps(
                        rotulo: 'Tempo em movimento',
                        valor: formatarCronometro(Duration(seconds: a.tempoMovimentoSegundos)),
                        grande: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GradeMetricas(
                  colunas: 3,
                  itens: [
                    MetricaGps(rotulo: '${media.rotulo} média', valor: media.valor, icone: Icons.speed_rounded),
                    MetricaGps(
                      rotulo: 'Vel. máxima',
                      valor: formatarVelocidade(a.velocidadeMaximaMps * 3.6),
                    ),
                    MetricaGps(
                      rotulo: 'Tempo total',
                      valor: formatarCronometro(Duration(seconds: a.tempoTotalSegundos)),
                      icone: Icons.timer_outlined,
                    ),
                    MetricaGps(
                      rotulo: 'Ganho de elevação',
                      valor: '${a.ganhoElevacao.round()} m',
                      icone: Icons.north_east_rounded,
                    ),
                    MetricaGps(
                      rotulo: 'Perda de elevação',
                      valor: '${a.perdaElevacao.round()} m',
                      icone: Icons.south_east_rounded,
                    ),
                    MetricaGps(
                      rotulo: 'Calorias',
                      valor: '${a.calorias} kcal',
                      icone: Icons.local_fire_department_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (a.parciais.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Titulo('Parciais por km'),
          const SizedBox(height: 8),
          _Parciais(tipo: a.tipo, parciais: a.parciais),
        ],
        const SizedBox(height: 24),
        const _Titulo('Comentário'),
        const SizedBox(height: 8),
        TextField(
          controller: comentario,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Como foi o treino? Sensações, clima, percurso...'),
        ),
        Text(
          'Calorias estimadas para 70 kg.',
          style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Parciais extends StatelessWidget {
  final TipoAtividadeGps tipo;
  final List<int> parciais;

  const _Parciais({required this.tipo, required this.parciais});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final maisRapido = parciais.reduce((a, b) => a < b ? a : b);
    final maisLento = parciais.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (i, segundos) in parciais.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text('${i + 1} km', style: tema.textTheme.labelLarge)),
                    SizedBox(
                      width: 92,
                      child: Text(
                        ritmoOuVelocidade(tipo, segundos.toDouble()).valor,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          fontWeight: segundos == maisRapido ? FontWeight.w700 : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          // Barra maior = km mais rápido.
                          value: maisLento == 0 ? 0 : (maisRapido / segundos).clamp(0.05, 1.0),
                          minHeight: 8,
                          backgroundColor: esquema.surfaceContainer,
                          color: segundos == maisRapido ? esquema.primary : esquema.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Text(
      texto.toUpperCase(),
      style: tema.textTheme.labelMedium?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
