import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/models/usuario.dart';
import 'package:focus/models/visao_geral.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/views/sessao_ativa_screen.dart';
import 'package:focus/widgets/atividade_gps_tile.dart';
import 'package:focus/widgets/atividades_do_dia.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/mapa_atividades.dart';
import 'package:focus/widgets/mapa_muscular.dart';
import 'package:focus/widgets/sessao_tile.dart';

/// Tela inicial: treino em andamento, sequência, totais da semana, histórico e mapa de atividades.
/// Treinos e atividades por GPS contam juntos em tudo.
class PainelInicio extends StatefulWidget {
  const PainelInicio({super.key});

  @override
  State<PainelInicio> createState() => _PainelInicioState();
}

class _PainelInicioState extends State<PainelInicio> {
  static const _quantidadeRecentes = 5;

  final _api = ApiService.instance;
  Usuario? _usuario;
  VisaoGeral? _visao;
  List<SessaoTreino> _recentes = [];
  List<AtividadeGps> _recentesGps = [];
  SessaoTreino? _sessaoAtiva;
  DateTime? _diaSelecionado;
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = _visao == null;
      _erro = null;
    });
    try {
      final resultados = await Future.wait<Object?>([
        _api.getUsuario(),
        _api.getVisaoGeral(),
        _api.getSessoes(limite: _quantidadeRecentes),
        _api.getSessaoAtiva(),
        _api.getAtividadesGps(limite: _quantidadeRecentes),
      ]);
      if (!mounted) return;
      setState(() {
        _usuario = resultados[0] as Usuario;
        _visao = resultados[1] as VisaoGeral;
        _recentes = resultados[2] as List<SessaoTreino>;
        _sessaoAtiva = resultados[3] as SessaoTreino?;
        _recentesGps = resultados[4] as List<AtividadeGps>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirSessao(SessaoTreino sessao) async {
    await abrirSessaoAtiva(context, sessao);
    if (mounted) await _carregarDados();
  }

  Future<void> _abrirAtividadeGps(AtividadeGps atividade) async {
    await abrirAtividadeGps(context, atividade);
    if (mounted) await _carregarDados();
  }

  /// Treinos e atividades por GPS mais recentes, misturados pela data de início.
  List<Widget> _itensRecentes() {
    final itens = <(DateTime, Widget)>[
      for (final sessao in _recentes)
        (
          sessao.iniciadaEm,
          SessaoTile(
            sessao: sessao,
            onTap: () => sessao.emAndamento ? _abrirSessao(sessao) : _abrirDia(sessao.iniciadaEm),
          ),
        ),
      for (final atividade in _recentesGps)
        (atividade.iniciadaEm, AtividadeGpsTile(atividade: atividade, onTap: () => _abrirAtividadeGps(atividade))),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, item) in itens.take(_quantidadeRecentes)) item];
  }

  Future<void> _abrirDia(DateTime dia) async {
    setState(() => _diaSelecionado = dia);
    await mostrarAtividadesDoDia(context, dia);
    if (mounted) setState(() => _diaSelecionado = null);
  }

  String get _saudacao {
    final hora = DateTime.now().hour;
    final periodo = hora < 12 ? 'Bom dia' : (hora < 18 ? 'Boa tarde' : 'Boa noite');
    final nome = _usuario?.primeiroNome ?? '';
    return nome.isEmpty ? periodo : '$periodo, $nome';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: const BotaoMenu(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_saudacao, style: tema.textTheme.bodyMedium?.copyWith(color: secundario)),
            Text('Seu progresso', style: tema.textTheme.headlineSmall),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? EstadoVazio(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não foi possível carregar',
                  mensagem: _erro,
                  rotuloAcao: 'Tentar novamente',
                  onAcao: _carregarDados,
                )
              : RefreshIndicator(onRefresh: _carregarDados, child: _conteudo(_visao!)),
    );
  }

  Widget _conteudo(VisaoGeral visao) {
    final semana = visao.semana;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_sessaoAtiva != null) ...[
          _BannerSessaoAtiva(sessao: _sessaoAtiva!, onTap: () => _abrirSessao(_sessaoAtiva!)),
          const SizedBox(height: 16),
        ],
        _CartaoSequencia(sequencia: visao.sequencia),
        const SizedBox(height: 32),
        _TituloSecao(titulo: 'Esta semana', detalhe: formatarIntervalo(semana.inicio, semana.fim)),
        const SizedBox(height: 12),
        _PainelSemana(semana: semana, onTapDia: _abrirDia),
        const SizedBox(height: 32),
        const _TituloSecao(titulo: 'Músculos da semana'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: semana.cargaMuscular.isEmpty
                ? Column(
                    children: [
                      const MapaMuscular(),
                      const SizedBox(height: 12),
                      Text(
                        'Finalize um treino marcando as séries feitas ou grave uma atividade no GPS para ver aqui os músculos que você mais trabalhou.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  )
                : ResumoMuscular(cargaMuscular: semana.cargaMuscular),
          ),
        ),
        const SizedBox(height: 32),
        const _TituloSecao(titulo: 'Atividades recentes'),
        const SizedBox(height: 12),
        if (_recentes.isEmpty && _recentesGps.isEmpty)
          const EstadoVazio(
            icone: Icons.fitness_center_rounded,
            titulo: 'Nenhuma atividade ainda',
            mensagem: 'Abra o menu ☰ e inicie um treino em Treinos ou grave uma corrida, pedal ou caminhada em GPS.',
          ),
        for (final item in _itensRecentes()) ...[
          item,
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 22),
        const _TituloSecao(titulo: 'Dias com atividade'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: MapaAtividades(mapa: visao.mapa, diaSelecionado: _diaSelecionado, onTapDia: _abrirDia),
          ),
        ),
      ],
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String titulo;
  final String? detalhe;

  const _TituloSecao({required this.titulo, this.detalhe});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estilo = tema.textTheme.labelMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        Expanded(child: Text(titulo.toUpperCase(), style: estilo)),
        if (detalhe != null) Text(detalhe!, style: estilo?.copyWith(letterSpacing: 0, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _BannerSessaoAtiva extends StatefulWidget {
  final SessaoTreino sessao;
  final VoidCallback onTap;

  const _BannerSessaoAtiva({required this.sessao, required this.onTap});

  @override
  State<_BannerSessaoAtiva> createState() => _BannerSessaoAtivaState();
}

class _BannerSessaoAtivaState extends State<_BannerSessaoAtiva> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final decorrido = DateTime.now().difference(widget.sessao.iniciadaEm);

    return Card(
      color: esquema.primary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: esquema.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: esquema.primary, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.play_arrow_rounded, color: esquema.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treino em andamento', style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary)),
                    Text(
                      widget.sessao.nomeTreino,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Text(
                formatarCronometro(decorrido),
                style: tema.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: esquema.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoSequencia extends StatelessWidget {
  final Sequencia sequencia;

  const _CartaoSequencia({required this.sequencia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ativa = sequencia.atual > 0;
    const laranja = Color(0xFFF97316);

    final mensagem = switch (sequencia) {
      Sequencia(atual: 0) => 'Treine ou grave uma atividade no GPS hoje para começar uma sequência.',
      Sequencia(treinouHoje: false) => 'Treine ou grave uma atividade no GPS hoje para não perder a sequência.',
      _ => 'Você já se exercitou hoje. Continue amanhã!',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ativa ? laranja.withValues(alpha: 0.14) : esquema.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 30,
                color: ativa ? laranja : esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sequencia.atual} ${sequencia.atual == 1 ? 'dia seguido' : 'dias seguidos'}',
                    style: tema.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(mensagem, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                ],
              ),
            ),
            if (sequencia.recorde > 0) ...[
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('${sequencia.recorde}', style: tema.textTheme.titleMedium),
                  Text('recorde', style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PainelSemana extends StatelessWidget {
  final ResumoSemana semana;
  final ValueChanged<DateTime> onTapDia;

  const _PainelSemana({required this.semana, required this.onTapDia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Column(
      children: [
        Card(
          color: esquema.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tempo ativo',
                        style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onPrimary.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatarDuracaoSegundos(semana.totalSegundos),
                        style: tema.textTheme.headlineMedium?.copyWith(color: esquema.onPrimary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.timer_outlined, size: 36, color: esquema.onPrimary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metrica(
                icone: Icons.calendar_today_rounded,
                rotulo: 'Atividades',
                valor: '${semana.totalAtividades}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metrica(
                icone: Icons.route_rounded,
                rotulo: 'Distância',
                valor: formatarDistancia(semana.totalDistanciaMetros),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metrica(icone: Icons.scale_outlined, rotulo: 'Carga total', valor: formatarVolume(semana.totalVolumeKg)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metrica(icone: Icons.repeat_rounded, rotulo: 'Séries', valor: '${semana.totalSeries}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GraficoSemana(dias: semana.dias, onTapDia: onTapDia),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _Metrica({required this.icone, required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 20, color: secundario),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: tema.textTheme.titleLarge),
            ),
            Text(rotulo, style: tema.textTheme.bodySmall?.copyWith(color: secundario)),
          ],
        ),
      ),
    );
  }
}

/// Barras de segunda a domingo com o tempo ativo em cada dia (treinos e GPS).
class _GraficoSemana extends StatelessWidget {
  final List<TotaisDoDia> dias;
  final ValueChanged<DateTime> onTapDia;

  const _GraficoSemana({required this.dias, required this.onTapDia});

  static const _letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
  static const _alturaMaxima = 72.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final hoje = inicioDoDia(DateTime.now());

    // Usa o tempo como medida; se nenhuma atividade foi finalizada, usa a quantidade.
    final usarTempo = dias.any((d) => d.duracaoSegundos > 0);
    double medida(TotaisDoDia d) => usarTempo ? d.duracaoSegundos.toDouble() : d.atividades.toDouble();
    final maximo = dias.map(medida).fold(0.0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, dia) in dias.indexed)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTapDia(dia.data),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 16,
                          child: dia.atividades > 0
                              ? Text(
                                  usarTempo ? '${(dia.duracaoSegundos / 60).round()}m' : '${dia.atividades}',
                                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 18,
                          height: maximo == 0 || medida(dia) == 0
                              ? 4
                              : 8 + (_alturaMaxima - 8) * (medida(dia) / maximo),
                          decoration: BoxDecoration(
                            color: dia.atividades > 0 ? esquema.primary : esquema.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _letras[i],
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: dia.data == hoje ? esquema.onSurface : esquema.onSurfaceVariant,
                            fontWeight: dia.data == hoje ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
