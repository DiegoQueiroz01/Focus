import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

/// O que foi escolhido na janela de quantidade.
sealed class EscolhaQuantidade {
  const EscolhaQuantidade();
}

class QuantidadeEscolhida extends EscolhaQuantidade {
  final Refeicao refeicao;
  final double gramas;
  final String? rotuloPorcao;

  const QuantidadeEscolhida({required this.refeicao, required this.gramas, this.rotuloPorcao});
}

class ExcluirRegistro extends EscolhaQuantidade {
  const ExcluirRegistro();
}

/// Abre a janela para escolher quanto foi comido. Com [registro], edita um item já lançado
/// (e oferece excluir).
Future<EscolhaQuantidade?> escolherQuantidade(
  BuildContext context, {
  required Alimento alimento,
  required Refeicao refeicao,
  RegistroAlimento? registro,
}) {
  return showModalBottomSheet<EscolhaQuantidade>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _QuantidadeSheet(alimento: alimento, refeicao: refeicao, registro: registro),
  );
}

String _semUm(String rotulo) => rotulo.startsWith('1 ') ? rotulo.substring(2) : rotulo;

String _qtd(double v) => (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1)).replaceAll('.', ',');

/// "1 colher de sopa", "2 × colher de sopa", "1,5 × unidade".
String rotuloPorcoes(Porcao porcao, double quantidade) =>
    quantidade == 1 ? porcao.rotulo : '${_qtd(quantidade)} × ${_semUm(porcao.rotulo)}';

class _QuantidadeSheet extends StatefulWidget {
  final Alimento alimento;
  final Refeicao refeicao;
  final RegistroAlimento? registro;

  const _QuantidadeSheet({required this.alimento, required this.refeicao, this.registro});

  @override
  State<_QuantidadeSheet> createState() => _QuantidadeSheetState();
}

class _QuantidadeSheetState extends State<_QuantidadeSheet> {
  /// null = em gramas.
  Porcao? _porcao;
  late Refeicao _refeicao = widget.refeicao;
  final _campo = TextEditingController();

  @override
  void initState() {
    super.initState();
    final registro = widget.registro;
    final porcoes = widget.alimento.porcoes;
    if (registro == null) {
      _porcao = porcoes.firstOrNull;
      _campo.text = _porcao == null ? '100' : '1';
      return;
    }
    // Tenta reabrir na mesma porção usada ao registrar.
    final rotulo = registro.rotuloPorcao;
    for (final p in porcoes) {
      if (rotulo == p.rotulo) {
        _porcao = p;
        _campo.text = '1';
        return;
      }
      final sufixo = ' × ${_semUm(p.rotulo)}';
      if (rotulo != null && rotulo.endsWith(sufixo)) {
        _porcao = p;
        _campo.text = rotulo.substring(0, rotulo.length - sufixo.length);
        return;
      }
    }
    _campo.text = _qtd(registro.gramas);
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  double? get _valor => double.tryParse(_campo.text.trim().replaceAll(',', '.'));

  double? get _gramas {
    final v = _valor;
    if (v == null || v <= 0) return null;
    return _porcao == null ? v : v * _porcao!.gramas;
  }

  void _mudarUnidade(Porcao? porcao) {
    setState(() {
      _porcao = porcao;
      _campo.text = porcao == null ? '100' : '1';
    });
  }

  void _somar(double delta) {
    final atual = _valor ?? 0;
    final novo = (atual + delta).clamp(0.5, 99).toDouble();
    setState(() => _campo.text = _qtd(novo));
  }

  void _confirmar() {
    final gramas = _gramas;
    if (gramas == null || gramas > 5000) return;
    Navigator.pop(
      context,
      QuantidadeEscolhida(
        refeicao: _refeicao,
        gramas: double.parse(gramas.toStringAsFixed(1)),
        rotuloPorcao: _porcao == null ? null : rotuloPorcoes(_porcao!, _valor!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final alimento = widget.alimento;
    final gramas = _gramas;
    final nutrientes = alimento.para(gramas ?? 0);
    final editando = widget.registro != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(alimento.nome, style: tema.textTheme.titleLarge),
              Text(
                '${formatarKcal(alimento.por100g.kcal)} kcal a cada 100 g · ${alimento.categoria}',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in alimento.porcoes)
                    ChoiceChip(
                      label: Text('${_semUm(p.rotulo)} (${formatarGramas(p.gramas)})'),
                      selected: _porcao == p,
                      onSelected: (_) => _mudarUnidade(p),
                    ),
                  ChoiceChip(
                    label: const Text('gramas'),
                    selected: _porcao == null,
                    onSelected: (_) => _mudarUnidade(null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_porcao != null)
                    IconButton.filledTonal(
                      onPressed: () => _somar(-0.5),
                      icon: const Icon(Icons.remove_rounded),
                      tooltip: 'Menos',
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: _campo,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.titleLarge,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: InputDecoration(
                          suffixText: _porcao == null ? 'g' : null,
                          helperText: _porcao != null && gramas != null ? '= ${formatarGramas(gramas)}' : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _confirmar(),
                      ),
                    ),
                  ),
                  if (_porcao != null)
                    IconButton.filledTonal(
                      onPressed: () => _somar(0.5),
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Mais',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatarKcal(nutrientes.kcal),
                          style: tema.textTheme.headlineSmall?.copyWith(color: esquema.primary),
                        ),
                        Text('kcal', style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LinhaMacros(
                        proteina: nutrientes.proteina,
                        carboidrato: nutrientes.carboidrato,
                        gordura: nutrientes.gordura,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Refeicao>(
                initialValue: _refeicao,
                decoration: const InputDecoration(labelText: 'Refeição'),
                items: [
                  for (final r in Refeicao.values)
                    DropdownMenuItem(
                      value: r,
                      child: Row(children: [Icon(r.icone, size: 18), const SizedBox(width: 10), Text(r.rotulo)]),
                    ),
                ],
                onChanged: (r) => setState(() => _refeicao = r ?? _refeicao),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: gramas == null || gramas > 5000 ? null : _confirmar,
                child: Text(editando ? 'Salvar' : 'Adicionar'),
              ),
              if (editando) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, const ExcluirRegistro()),
                  style: TextButton.styleFrom(foregroundColor: esquema.error, minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remover da refeição'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
