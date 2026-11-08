import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/catalogo_exercicios_screen.dart';
import 'package:focus/widgets/imagem_exercicio.dart';

/// Cria um treino novo ou, se [treino] for informado, edita um existente.
/// Retorna o treino salvo.
class TreinoFormScreen extends StatefulWidget {
  final Treino? treino;

  const TreinoFormScreen({super.key, this.treino});

  @override
  State<TreinoFormScreen> createState() => _TreinoFormScreenState();
}

class _TreinoFormScreenState extends State<TreinoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeSessaoController = TextEditingController(text: widget.treino?.nomeSessao);
  late final List<Exercicio> _exercicios = List.of(widget.treino?.exercicios ?? const []);
  late TipoTreino _tipo = widget.treino?.tipo ?? TipoTreino.musculacao;
  bool _salvando = false;

  bool get _editando => widget.treino?.id != null;

  @override
  void dispose() {
    _nomeSessaoController.dispose();
    super.dispose();
  }

  /// Escolhe um exercício do catálogo (ou cria um personalizado) e define séries e carga.
  Future<void> _adicionarExercicio() async {
    final escolha = await Navigator.push<EscolhaCatalogo>(
      context,
      MaterialPageRoute(builder: (_) => CatalogoExerciciosScreen(tipoInicial: _tipo)),
    );
    if (escolha == null || !mounted) return;
    final rascunho = switch (escolha) {
      ExercicioEscolhido(:final exercicio) => Exercicio(
          nome: exercicio.nome,
          grupoMuscular: exercicio.grupoMuscular,
          catalogoId: exercicio.id,
          series: 0,
        ),
      ExercicioPersonalizado(:final nome) => Exercicio(nome: nome, series: 0),
    };
    await _abrirFormularioExercicio(rascunho: rascunho);
  }

  Future<void> _abrirFormularioExercicio({int? indice, Exercicio? rascunho}) async {
    final exercicio = await showModalBottomSheet<Exercicio>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormularioExercicio(
        inicial: indice == null ? rascunho : _exercicios[indice],
        editando: indice != null,
      ),
    );
    if (exercicio == null) return;
    setState(() {
      if (indice == null) {
        _exercicios.add(exercicio);
      } else {
        _exercicios[indice] = exercicio;
      }
    });
  }

  Future<void> _salvarTreino() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    final treino = Treino(
      nomeSessao: _nomeSessaoController.text.trim(),
      tipo: _tipo,
      exercicios: List.of(_exercicios),
    );
    try {
      final salvo = _editando
          ? await ApiService.instance.atualizarTreino(widget.treino!.id!, treino)
          : await ApiService.instance.criarTreino(treino);
      if (!mounted) return;
      Navigator.pop(context, salvo);
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
      appBar: AppBar(title: Text(_editando ? 'Editar treino' : 'Novo treino')),
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
            const _Rotulo(texto: 'Tipo'),
            const SizedBox(height: 8),
            SegmentedButton<TipoTreino>(
              showSelectedIcon: false,
              segments: [
                for (final tipo in TipoTreino.values) ButtonSegment(value: tipo, label: Text(tipo.rotulo)),
              ],
              selected: {_tipo},
              onSelectionChanged: (selecao) => setState(() => _tipo = selecao.first),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: _Rotulo(texto: 'Exercícios')),
                TextButton.icon(
                  onPressed: _adicionarExercicio,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_exercicios.isEmpty)
              _BotaoTracejado(onTap: _adicionarExercicio)
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (indice, ex) in _exercicios.indexed) ...[
                      if (indice > 0) const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        onTap: () => _abrirFormularioExercicio(indice: indice),
                        contentPadding: const EdgeInsets.only(left: 12, right: 4),
                        leading: MiniaturaExercicio(
                          catalogoId: ex.catalogoId,
                          abreDetalhe: false,
                          semCatalogo: ImagemExercicio(largura: 48, altura: 48),
                        ),
                        title: Text(ex.nome, style: tema.textTheme.titleSmall),
                        subtitle: Text(
                          '${ex.grupoMuscular.rotulo}  ·  ${ex.series} séries  ·  '
                          '${ex.repeticoes} reps  ·  ${ex.cargaFormatada}',
                          style: tema.textTheme.bodySmall?.copyWith(color: secundario),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Remover',
                          onPressed: () => setState(() => _exercicios.removeAt(indice)),
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
              : Text(_editando ? 'Salvar alterações' : 'Salvar treino'),
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
              Text('Nenhum exercício adicionado', style: TextStyle(color: esquema.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                'Toque para escolher no catálogo',
                style: TextStyle(color: esquema.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormularioExercicio extends StatefulWidget {
  final Exercicio? inicial;
  final bool editando;

  const _FormularioExercicio({this.inicial, this.editando = false});

  @override
  State<_FormularioExercicio> createState() => _FormularioExercicioState();
}

class _FormularioExercicioState extends State<_FormularioExercicio> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.inicial?.nome);
  late final _seriesController = TextEditingController(text: _textoInteiro(widget.inicial?.series));
  late final _repeticoesController = TextEditingController(text: _textoInteiro(widget.inicial?.repeticoes));
  late final _cargaController = TextEditingController(text: _textoCarga(widget.inicial?.cargaKg));
  late GrupoMuscular? _grupo = widget.inicial?.grupoMuscular;

  static String? _textoInteiro(int? valor) => (valor == null || valor == 0) ? null : '$valor';

  static String? _textoCarga(double? kg) {
    if (kg == null || kg == 0) return null;
    return kg == kg.truncateToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  }

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
        grupoMuscular: _grupo ?? GrupoMuscular.outro,
        catalogoId: widget.inicial?.catalogoId,
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
            Row(
              children: [
                if (widget.inicial?.catalogoId != null) ...[
                  MiniaturaExercicio(
                    catalogoId: widget.inicial!.catalogoId,
                    tamanho: 44,
                    semCatalogo: const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(widget.editando ? 'Editar exercício' : 'Novo exercício', style: tema.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomeController,
              autofocus: (widget.inicial?.nome ?? '').isEmpty,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              decoration: const InputDecoration(labelText: 'Exercício', counterText: ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GrupoMuscular>(
              initialValue: _grupo,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              menuMaxHeight: 360,
              validator: (v) => v == null ? 'Escolha o grupo muscular' : null,
              decoration: const InputDecoration(
                labelText: 'Grupo muscular',
                prefixIcon: Icon(Icons.accessibility_new_rounded),
              ),
              items: [
                for (final grupo in GrupoMuscular.values)
                  DropdownMenuItem(value: grupo, child: Text(grupo.rotulo)),
              ],
              onChanged: (grupo) => setState(() => _grupo = grupo),
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
            FilledButton(
              onPressed: _confirmar,
              child: Text(widget.editando ? 'Salvar exercício' : 'Adicionar exercício'),
            ),
          ],
        ),
      ),
    );
  }
}
