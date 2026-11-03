import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';

class TreinoFormScreen extends StatefulWidget {
  const TreinoFormScreen({super.key});

  @override
  State<TreinoFormScreen> createState() => _TreinoFormScreenState();
}

class _TreinoFormScreenState extends State<TreinoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeSessaoController = TextEditingController();
  final _duracaoController = TextEditingController();
  final List<Exercicio> _exerciciosAdicionados = [];
  TipoTreino _tipo = TipoTreino.musculacao;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeSessaoController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  Future<void> _abrirFormularioExercicio() async {
    final exercicio = await showModalBottomSheet<Exercicio>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _FormularioExercicio(),
    );
    if (exercicio != null) {
      setState(() => _exerciciosAdicionados.add(exercicio));
    }
  }

  Future<void> _salvarTreino() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final criado = await ApiService.instance.criarTreino(Treino(
        nomeSessao: _nomeSessaoController.text.trim(),
        tipo: _tipo,
        tempoTotalMinutos: int.tryParse(_duracaoController.text) ?? 0,
        exercicios: List.of(_exerciciosAdicionados),
      ));
      if (!mounted) return;
      Navigator.pop(context, criado);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo treino')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextFormField(
              controller: _nomeSessaoController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome da sessão' : null,
              decoration: const InputDecoration(
                labelText: 'Nome da sessão',
                hintText: 'Ex.: Treino A — Peito e tríceps',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            _Rotulo(texto: 'Tipo'),
            const SizedBox(height: 8),
            SegmentedButton<TipoTreino>(
              showSelectedIcon: false,
              segments: [
                for (final tipo in TipoTreino.values)
                  ButtonSegment(value: tipo, label: Text(tipo.rotulo)),
              ],
              selected: {_tipo},
              onSelectionChanged: (selecao) => setState(() => _tipo = selecao.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _duracaoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final minutos = int.tryParse(v ?? '');
                if (minutos == null || minutos <= 0) return 'Informe a duração';
                if (minutos > 1440) return 'Máximo de 1440 minutos';
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Duração',
                suffixText: 'min',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: _Rotulo(texto: 'Exercícios')),
                TextButton.icon(
                  onPressed: _abrirFormularioExercicio,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_exerciciosAdicionados.isEmpty)
              _BotaoTracejado(onTap: _abrirFormularioExercicio)
            else
              Card(
                child: Column(
                  children: [
                    for (final (indice, ex) in _exerciciosAdicionados.indexed) ...[
                      if (indice > 0) const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 16, right: 4),
                        title: Text(ex.nome, style: tema.textTheme.titleSmall),
                        subtitle: Text(
                          '${ex.series} séries  ·  ${ex.repeticoes} reps  ·  ${ex.cargaFormatada}',
                          style: tema.textTheme.bodySmall?.copyWith(color: secundario),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Remover',
                          onPressed: () => setState(() => _exerciciosAdicionados.removeAt(indice)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _salvando ? null : _salvarTreino,
          child: _salvando
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar treino'),
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;

  const _Rotulo({required this.texto});

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

class _BotaoTracejado extends StatelessWidget {
  final VoidCallback onTap;

  const _BotaoTracejado({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: esquema.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Nenhum exercício adicionado',
                style: TextStyle(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormularioExercicio extends StatefulWidget {
  const _FormularioExercicio();

  @override
  State<_FormularioExercicio> createState() => _FormularioExercicioState();
}

class _FormularioExercicioState extends State<_FormularioExercicio> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _seriesController = TextEditingController();
  final _cargaController = TextEditingController();
  final _repeticoesController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _seriesController.dispose();
    _cargaController.dispose();
    _repeticoesController.dispose();
    super.dispose();
  }

  String? _inteiroNoIntervalo(String? valor, int maximo) {
    if (valor == null || valor.isEmpty) return null;
    final numero = int.tryParse(valor);
    if (numero == null || numero > maximo) return 'Máx. $maximo';
    return null;
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Exercicio(
        nome: _nomeController.text.trim(),
        series: int.tryParse(_seriesController.text) ?? 0,
        cargaKg: double.tryParse(_cargaController.text.replaceAll(',', '.')) ?? 0,
        repeticoes: int.tryParse(_repeticoesController.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo exercício', style: tema.textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomeController,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              decoration: const InputDecoration(labelText: 'Exercício', counterText: ''),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seriesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : _inteiroNoIntervalo(v, 100),
                    decoration: const InputDecoration(labelText: 'Séries'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _repeticoesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _inteiroNoIntervalo(v, 1000),
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cargaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final carga = double.tryParse(v.replaceAll(',', '.'));
                      return (carga == null || carga > 9999.99) ? 'Inválida' : null;
                    },
                    decoration: const InputDecoration(labelText: 'Carga', suffixText: 'kg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _confirmar, child: const Text('Adicionar exercício')),
          ],
        ),
      ),
    );
  }
}
