import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focus/models/dashboard_resumo.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/login_screen.dart';
import 'package:focus/views/treinos_detalhes_screen.dart';
import 'package:focus/views/treinos_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/treino_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _indiceAtual = 0;

  final List<Widget> _telas = [
    const PainelResumo(),
    const TreinoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_indiceAtual],
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _indiceAtual,
          onDestinationSelected: (index) => setState(() => _indiceAtual = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted_rounded),
              selectedIcon: Icon(Icons.format_list_bulleted_rounded),
              label: 'Treinos',
            ),
          ],
        ),
      ),
    );
  }
}

class PainelResumo extends StatefulWidget {
  const PainelResumo({super.key});

  @override
  State<PainelResumo> createState() => _PainelResumoState();
}

class _PainelResumoState extends State<PainelResumo> {
  static const _diasDoResumo = 7;
  static const _quantidadeRecentes = 5;

  final _api = ApiService.instance;
  DashboardResumo? _resumo;
  List<Treino> _recentes = [];
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = _resumo == null;
      _erro = null;
    });
    try {
      final (resumo, pagina) = await (
        _api.getResumo(dias: _diasDoResumo),
        _api.getTreinos(limit: _quantidadeRecentes),
      ).wait;
      if (!mounted) return;
      setState(() {
        _resumo = resumo;
        _recentes = pagina.itens;
      });
    } on ParallelWaitError<dynamic, (AsyncError?, AsyncError?)> catch (e) {
      final erro = e.errors.$1?.error ?? e.errors.$2?.error;
      if (mounted) setState(() => _erro = erro.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _fazerLogoff() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_saudacao, style: tema.textTheme.bodyMedium?.copyWith(color: secundario)),
            Text('Seu progresso', style: tema.textTheme.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _fazerLogoff,
            tooltip: 'Sair',
          ),
          const SizedBox(width: 8),
        ],
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
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _TituloSecao(titulo: 'Últimos 7 dias'),
                      const SizedBox(height: 12),
                      _PainelMetricas(resumo: _resumo!),
                      const SizedBox(height: 32),
                      _TituloSecao(titulo: 'Atividades recentes'),
                      const SizedBox(height: 12),
                      if (_recentes.isEmpty)
                        const EstadoVazio(
                          icone: Icons.fitness_center_rounded,
                          titulo: 'Nenhum treino ainda',
                          mensagem: 'Registre sua primeira sessão na aba Treinos.',
                        ),
                      for (final treino in _recentes) ...[
                        TreinoTile(
                          treino: treino,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TreinoDetalhesScreen(treino: treino)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String titulo;

  const _TituloSecao({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Text(
      titulo.toUpperCase(),
      style: tema.textTheme.labelMedium?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PainelMetricas extends StatelessWidget {
  final DashboardResumo resumo;

  const _PainelMetricas({required this.resumo});

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
                        'Tempo de treino',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: esquema.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatarDuracao(resumo.tempoTotalMinutos),
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
              child: _Metrica(icone: Icons.calendar_today_rounded, rotulo: 'Treinos', valor: '${resumo.totalTreinos}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metrica(icone: Icons.repeat_rounded, rotulo: 'Séries', valor: '${resumo.seriesTotais}'),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 20, color: secundario),
            const SizedBox(height: 14),
            Text(valor, style: tema.textTheme.headlineSmall),
            Text(rotulo, style: tema.textTheme.bodySmall?.copyWith(color: secundario)),
          ],
        ),
      ),
    );
  }
}
