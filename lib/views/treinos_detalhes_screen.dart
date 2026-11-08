import 'package:flutter/material.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/sessao_ativa_screen.dart';
import 'package:focus/views/treino_form_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/treino_tile.dart';

/// Detalhes de um treino, com o botão para iniciá-lo. Ao fechar, retorna true se o
/// treino foi editado ou excluído (para a lista recarregar).
class TreinoDetalhesScreen extends StatefulWidget {
  final Treino treino;

  const TreinoDetalhesScreen({super.key, required this.treino});

  @override
  State<TreinoDetalhesScreen> createState() => _TreinoDetalhesScreenState();
}

class _TreinoDetalhesScreenState extends State<TreinoDetalhesScreen> {
  final _api = ApiService.instance;
  late Treino _treino = widget.treino;
  bool _alterado = false;
  bool _ocupado = false;

  Future<void> _iniciar() async {
    setState(() => _ocupado = true);
    try {
      final sessao = await _api.iniciarSessao(_treino.id!);
      if (!mounted) return;
      await abrirSessaoAtiva(context, sessao, treino: _treino);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _oferecerSessaoEmAndamento(e.mensagem);
      } else {
        _mostrarErro(e.mensagem);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Já existe um treino em andamento: oferece voltar para ele.
  Future<void> _oferecerSessaoEmAndamento(String mensagem) async {
    final ativa = await _api.getSessaoAtiva();
    if (!mounted || ativa == null) return;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Treino em andamento'),
        content: Text('"${ativa.nomeTreino}" ainda está aberto. Finalize-o antes de iniciar outro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ir para o treino')),
        ],
      ),
    );
    if (continuar == true && mounted) {
      await abrirSessaoAtiva(context, ativa, treino: ativa.treinoId == _treino.id ? _treino : null);
    }
  }

  Future<void> _editar() async {
    final atualizado = await Navigator.push<Treino>(
      context,
      MaterialPageRoute(builder: (_) => TreinoFormScreen(treino: _treino)),
    );
    if (atualizado != null) {
      setState(() {
        _treino = atualizado;
        _alterado = true;
      });
    }
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text(
          '"${_treino.nomeSessao}" será removido. As sessões já realizadas continuam no seu histórico.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _ocupado = true);
    try {
      await _api.excluirTreino(_treino.id!);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    final grupos = _treino.gruposMusculares.map((g) => g.rotulo).join(', ');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _alterado);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: _ocupado ? null : _editar,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Excluir',
              onPressed: _ocupado ? null : _excluir,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconeTreino(tipo: _treino.tipo, nome: _treino.nomeSessao, tamanho: 52),
            ),
            const SizedBox(height: 16),
            Text(_treino.nomeSessao, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              [_treino.tipo.rotulo, if (grupos.isNotEmpty) grupos].join('  ·  '),
              style: tema.textTheme.bodyMedium?.copyWith(color: secundario),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _Estatistica(rotulo: 'Exercícios', valor: '${_treino.exercicios.length}'),
                      const VerticalDivider(),
                      _Estatistica(rotulo: 'Séries', valor: '${_treino.seriesTotais}'),
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
            if (_treino.exercicios.isEmpty)
              const EstadoVazio(
                icone: Icons.list_alt_rounded,
                titulo: 'Sem exercícios',
                mensagem: 'Edite o treino para adicionar exercícios.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final (indice, ex) in _treino.exercicios.indexed) ...[
                      if (indice > 0) const Divider(indent: 64),
                      _LinhaExercicio(numero: indice + 1, exercicio: ex),
                    ],
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _ocupado ? null : _iniciar,
            icon: _ocupado
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded, size: 26),
            label: const Text('Iniciar treino'),
          ),
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercicio.nome, style: tema.textTheme.titleSmall),
                Text(
                  exercicio.grupoMuscular.rotulo,
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(volume, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        ],
      ),
    );
  }
}
