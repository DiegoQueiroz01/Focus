import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/service/progresso_sessao_storage.dart';
import 'package:focus/utils/formatadores.dart';

/// Abre a tela de uma sessão em andamento. Se o plano não for informado, busca na API
/// (ele pode ter sido excluído; nesse caso a sessão segue só com o cronômetro).
/// Retorna true se a sessão foi finalizada ou descartada.
Future<bool> abrirSessaoAtiva(BuildContext context, SessaoTreino sessao, {Treino? treino}) async {
  var plano = treino;
  if (plano == null && sessao.treinoId != null) {
    try {
      plano = await ApiService.instance.getTreino(sessao.treinoId!);
    } on ApiException {
      plano = null;
    }
  }
  if (!context.mounted) return false;
  final encerrou = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => SessaoAtivaScreen(sessao: sessao, treino: plano)),
  );
  return encerrou ?? false;
}

class _Serie {
  int repeticoes;
  double cargaKg;
  bool feita = false;

  _Serie({required this.repeticoes, required this.cargaKg});

  double get volume => repeticoes * cargaKg;

  Map<String, dynamic> toJson() => {'r': repeticoes, 'c': cargaKg, 'f': feita};
}

class SessaoAtivaScreen extends StatefulWidget {
  final SessaoTreino sessao;
  final Treino? treino;

  const SessaoAtivaScreen({super.key, required this.sessao, this.treino});

  @override
  State<SessaoAtivaScreen> createState() => _SessaoAtivaScreenState();
}

class _SessaoAtivaScreenState extends State<SessaoAtivaScreen> {
  final _progresso = ProgressoSessaoStorage.instance;
  late final List<Exercicio> _exercicios = widget.treino?.exercicios ?? const [];
  late final List<List<_Serie>> _series = [
    for (final e in _exercicios)
      [for (var i = 0; i < e.series; i++) _Serie(repeticoes: e.repeticoes, cargaKg: e.cargaKg)],
  ];

  /// Séries concluídas na ordem em que foram marcadas: (exercício, série).
  final List<(int, int)> _ordemConcluidas = [];

  Timer? _timer;
  Duration _decorrido = Duration.zero;
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    _atualizarCronometro();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _atualizarCronometro());
    _restaurarProgresso();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _atualizarCronometro() {
    // Calculado a partir do horário de início, então continua certo mesmo com o app em segundo plano.
    setState(() => _decorrido = DateTime.now().difference(widget.sessao.iniciadaEm));
  }

  // --- Progresso local

  Future<void> _restaurarProgresso() async {
    final salvo = await _progresso.ler(widget.sessao.id);
    if (salvo == null || !mounted) return;
    try {
      final series = (salvo['series'] as List).cast<List<dynamic>>();
      final mesmaEstrutura = series.length == _series.length &&
          [for (var i = 0; i < series.length; i++) series[i].length == _series[i].length].every((ok) => ok);
      if (!mesmaEstrutura) return;

      setState(() {
        for (var e = 0; e < series.length; e++) {
          for (var s = 0; s < series[e].length; s++) {
            final dado = series[e][s] as Map<String, dynamic>;
            _series[e][s]
              ..repeticoes = (dado['r'] as num).toInt()
              ..cargaKg = (dado['c'] as num).toDouble()
              ..feita = dado['f'] as bool;
          }
        }
        _ordemConcluidas
          ..clear()
          ..addAll([
            for (final par in salvo['ordem'] as List)
              ((par as List)[0] as int, par[1] as int),
          ].where((p) => _series[p.$1][p.$2].feita));
      });
    } catch (_) {
      // Progresso salvo em formato inesperado: começa do zero.
    }
  }

  void _salvarProgresso() {
    _progresso.salvar(widget.sessao.id, {
      'series': [
        for (final lista in _series) [for (final s in lista) s.toJson()],
      ],
      'ordem': [
        for (final (e, s) in _ordemConcluidas) [e, s],
      ],
    });
  }

  // --- Métricas

  double get _volumeTotal {
    var total = 0.0;
    for (final lista in _series) {
      for (final s in lista) {
        if (s.feita) total += s.volume;
      }
    }
    return total;
  }

  int get _seriesFeitas => _ordemConcluidas.length;

  int get _seriesPlanejadas => _series.fold(0, (soma, lista) => soma + lista.length);

  GrupoMuscular? get _ultimoGrupo =>
      _ordemConcluidas.isEmpty ? null : _exercicios[_ordemConcluidas.last.$1].grupoMuscular;

  // --- Ações

  void _alternarSerie(int exercicio, int serie) {
    HapticFeedback.selectionClick();
    setState(() {
      final alvo = _series[exercicio][serie];
      alvo.feita = !alvo.feita;
      if (alvo.feita) {
        _ordemConcluidas.add((exercicio, serie));
      } else {
        _ordemConcluidas.remove((exercicio, serie));
      }
    });
    _salvarProgresso();
  }

  Future<void> _editarSerie(int exercicio, int serie) async {
    final atual = _series[exercicio][serie];
    final resultado = await showDialog<(int, double, bool)>(
      context: context,
      builder: (_) => _DialogoSerie(
        numero: serie + 1,
        repeticoes: atual.repeticoes,
        cargaKg: atual.cargaKg,
        temSeguintes: serie < _series[exercicio].length - 1,
      ),
    );
    if (resultado == null) return;
    final (repeticoes, carga, aplicarSeguintes) = resultado;
    setState(() {
      final lista = _series[exercicio];
      for (var i = serie; i < lista.length; i++) {
        if (i == serie || (aplicarSeguintes && !lista[i].feita)) {
          lista[i]
            ..repeticoes = repeticoes
            ..cargaKg = carga;
        }
      }
    });
    _salvarProgresso();
  }

  Future<void> _finalizar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar treino?'),
        content: Text(
          _seriesPlanejadas > 0 && _seriesFeitas < _seriesPlanejadas
              ? 'Você concluiu $_seriesFeitas de $_seriesPlanejadas séries. O treino será salvo assim mesmo.'
              : 'O tempo, a carga e as séries serão salvos no seu histórico.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar treinando')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _encerrando = true);
    try {
      final finalizada = await ApiService.instance.finalizarSessao(
        widget.sessao.id,
        volumeKg: _volumeTotal,
        series: _seriesFeitas,
        ultimoGrupo: _ultimoGrupo,
      );
      await _progresso.apagar(widget.sessao.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _DialogoConcluido(sessao: finalizada));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _encerrando = false);
    }
  }

  Future<void> _descartar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar treino?'),
        content: const Text('Esta sessão será apagada e não contará no seu histórico nem na sequência.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _encerrando = true);
    try {
      await ApiService.instance.descartarSessao(widget.sessao.id);
      await _progresso.apagar(widget.sessao.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _encerrando = false);
    }
  }

  Future<void> _aoTentarSair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do treino?'),
        content: const Text(
          'O cronômetro continua contando. Você pode voltar a este treino pelo painel inicial.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ficar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (sair == true && mounted) Navigator.pop(context, false);
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  // --- Interface

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_encerrando) _aoTentarSair();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sessao.nomeTreino, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<void>(
              tooltip: 'Mais opções',
              enabled: !_encerrando,
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: _descartar,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Descartar treino'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _PainelAoVivo(
              decorrido: _decorrido,
              volumeKg: _volumeTotal,
              seriesFeitas: _seriesFeitas,
              seriesPlanejadas: _seriesPlanejadas,
              ultimoGrupo: _ultimoGrupo,
            ),
            const SizedBox(height: 24),
            if (_exercicios.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    widget.sessao.treinoId == null || widget.treino == null
                        ? 'Os exercícios deste treino não estão mais disponíveis. O cronômetro segue valendo.'
                        : 'Este treino não tem exercícios cadastrados. O cronômetro registra o tempo da sessão.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            for (final (e, exercicio) in _exercicios.indexed) ...[
              _CartaoExercicio(
                exercicio: exercicio,
                series: _series[e],
                destacado: _ordemConcluidas.isNotEmpty && _ordemConcluidas.last.$1 == e,
                onAlternar: (s) => _alternarSerie(e, s),
                onEditar: (s) => _editarSerie(e, s),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _encerrando ? null : _finalizar,
            icon: _encerrando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.stop_rounded),
            label: const Text('Finalizar treino'),
          ),
        ),
      ),
    );
  }
}

class _PainelAoVivo extends StatelessWidget {
  final Duration decorrido;
  final double volumeKg;
  final int seriesFeitas;
  final int seriesPlanejadas;
  final GrupoMuscular? ultimoGrupo;

  const _PainelAoVivo({
    required this.decorrido,
    required this.volumeKg,
    required this.seriesFeitas,
    required this.seriesPlanejadas,
    required this.ultimoGrupo,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final suave = esquema.onPrimary.withValues(alpha: 0.75);

    Widget metrica(String rotulo, String valor) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo, style: tema.textTheme.bodySmall?.copyWith(color: suave)),
              const SizedBox(height: 2),
              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleMedium?.copyWith(color: esquema.onPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    return Card(
      color: esquema.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: suave),
                const SizedBox(width: 6),
                Text('Tempo de treino', style: tema.textTheme.bodyMedium?.copyWith(color: suave)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatarCronometro(decorrido),
              style: tema.textTheme.displayMedium?.copyWith(
                color: esquema.onPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                metrica('Carga total', formatarVolume(volumeKg)),
                metrica('Séries', seriesPlanejadas > 0 ? '$seriesFeitas/$seriesPlanejadas' : '$seriesFeitas'),
                metrica('Último grupo', ultimoGrupo?.rotulo ?? '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoExercicio extends StatelessWidget {
  final Exercicio exercicio;
  final List<_Serie> series;
  final bool destacado;
  final ValueChanged<int> onAlternar;
  final ValueChanged<int> onEditar;

  const _CartaoExercicio({
    required this.exercicio,
    required this.series,
    required this.destacado,
    required this.onAlternar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final concluidas = series.where((s) => s.feita).length;
    final volume = series.where((s) => s.feita).fold(0.0, (soma, s) => soma + s.volume);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: destacado ? esquema.primary : esquema.outlineVariant, width: destacado ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercicio.nome, style: tema.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        [
                          exercicio.grupoMuscular.rotulo,
                          '$concluidas/${series.length} séries',
                          if (volume > 0) formatarVolume(volume),
                        ].join('  ·  '),
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (series.isNotEmpty && concluidas == series.length)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle_rounded, color: esquema.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (i, serie) in series.indexed)
              _LinhaSerie(
                numero: i + 1,
                serie: serie,
                onAlternar: () => onAlternar(i),
                onEditar: () => onEditar(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinhaSerie extends StatelessWidget {
  final int numero;
  final _Serie serie;
  final VoidCallback onAlternar;
  final VoidCallback onEditar;

  const _LinhaSerie({required this.numero, required this.serie, required this.onAlternar, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final feita = serie.feita;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: feita ? esquema.primary.withValues(alpha: 0.14) : esquema.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$numero', style: tema.textTheme.labelMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onEditar,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Text(
                    '${serie.repeticoes} reps  ×  ${formatarCarga(serie.cargaKg)}',
                    style: tema.textTheme.bodyLarge?.copyWith(
                      color: feita ? esquema.onSurfaceVariant : esquema.onSurface,
                      decoration: feita ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 14, color: esquema.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        Checkbox(
          value: feita,
          onChanged: (_) => onAlternar(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ],
    );
  }
}

class _DialogoSerie extends StatefulWidget {
  final int numero;
  final int repeticoes;
  final double cargaKg;
  final bool temSeguintes;

  const _DialogoSerie({
    required this.numero,
    required this.repeticoes,
    required this.cargaKg,
    required this.temSeguintes,
  });

  @override
  State<_DialogoSerie> createState() => _DialogoSerieState();
}

class _DialogoSerieState extends State<_DialogoSerie> {
  final _formKey = GlobalKey<FormState>();
  late final _repsController = TextEditingController(text: '${widget.repeticoes}');
  late final _cargaController = TextEditingController(
    text: widget.cargaKg == widget.cargaKg.truncateToDouble()
        ? widget.cargaKg.toStringAsFixed(0)
        : widget.cargaKg.toString(),
  );
  bool _aplicarSeguintes = true;

  @override
  void dispose() {
    _repsController.dispose();
    _cargaController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      int.parse(_repsController.text),
      double.tryParse(_cargaController.text.replaceAll(',', '.')) ?? 0,
      widget.temSeguintes && _aplicarSeguintes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Série ${widget.numero}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n > 1000) ? 'Inválido' : null;
                    },
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
            if (widget.temSeguintes)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _aplicarSeguintes,
                onChanged: (v) => setState(() => _aplicarSeguintes = v ?? false),
                title: const Text('Aplicar às séries seguintes'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirmar, child: const Text('Salvar')),
      ],
    );
  }
}

class _DialogoConcluido extends StatelessWidget {
  final SessaoTreino sessao;

  const _DialogoConcluido({required this.sessao});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    Widget linha(IconData icone, String rotulo, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icone, size: 20, color: esquema.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(rotulo)),
              Text(valor, style: tema.textTheme.titleSmall),
            ],
          ),
        );

    return AlertDialog(
      icon: Icon(Icons.emoji_events_rounded, color: esquema.primary, size: 36),
      title: const Text('Treino concluído!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          linha(Icons.timer_outlined, 'Tempo', formatarDuracaoSegundos(sessao.duracaoSegundos)),
          linha(Icons.scale_outlined, 'Carga total', formatarVolume(sessao.volumeTotalKg)),
          linha(Icons.repeat_rounded, 'Séries', '${sessao.seriesTotais}'),
          if (sessao.ultimoGrupoMuscular != null)
            linha(Icons.accessibility_new_rounded, 'Último grupo', sessao.ultimoGrupoMuscular!.rotulo),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
