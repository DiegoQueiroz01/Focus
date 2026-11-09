import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';

/// Cadastro de um alimento que não está na base (ex.: um produto do mercado),
/// copiando a tabela nutricional do rótulo. Retorna o alimento criado.
class NovoAlimentoScreen extends StatefulWidget {
  final String nomeInicial;

  const NovoAlimentoScreen({super.key, this.nomeInicial = ''});

  @override
  State<NovoAlimentoScreen> createState() => _NovoAlimentoScreenState();
}

class _NovoAlimentoScreenState extends State<NovoAlimentoScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.nomeInicial);
  final _porcao = TextEditingController(text: '100');
  final _rotuloPorcao = TextEditingController();
  final _kcal = TextEditingController();
  final _proteina = TextEditingController();
  final _carbo = TextEditingController();
  final _gordura = TextEditingController();
  final _fibra = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_nome, _porcao, _rotuloPorcao, _kcal, _proteina, _carbo, _gordura, _fibra]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _ler(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    final rotulo = _rotuloPorcao.text.trim();
    try {
      final alimento = await ApiService.instance.criarAlimento(NovoAlimento(
        nome: _nome.text.trim(),
        porcaoGramas: _ler(_porcao.text)!,
        rotuloPorcao: rotulo.isEmpty ? null : rotulo,
        porPorcao: Nutrientes(
          kcal: _ler(_kcal.text)!,
          proteina: _ler(_proteina.text) ?? 0,
          carboidrato: _ler(_carbo.text) ?? 0,
          gordura: _ler(_gordura.text) ?? 0,
          fibra: _ler(_fibra.text) ?? 0,
        ),
      ));
      if (mounted) Navigator.pop(context, alimento);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Novo alimento')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Copie os valores da tabela nutricional do rótulo. Ele fica salvo só para você.',
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Iogurte proteico da marca X'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Numero(controller: _porcao, rotulo: 'Porção', sufixo: 'g', obrigatorio: true, maiorQueZero: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rotuloPorcao,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Nome da porção', hintText: '1 pote', counterText: ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Valores nesta porção', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            _Numero(controller: _kcal, rotulo: 'Calorias', sufixo: 'kcal', obrigatorio: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Numero(controller: _proteina, rotulo: 'Proteínas', sufixo: 'g')),
                const SizedBox(width: 12),
                Expanded(child: _Numero(controller: _carbo, rotulo: 'Carboidratos', sufixo: 'g')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Numero(controller: _gordura, rotulo: 'Gorduras totais', sufixo: 'g')),
                const SizedBox(width: 12),
                Expanded(child: _Numero(controller: _fibra, rotulo: 'Fibras', sufixo: 'g')),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Salvar alimento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  final TextEditingController controller;
  final String rotulo;
  final String sufixo;
  final bool obrigatorio;
  final bool maiorQueZero;

  const _Numero({
    required this.controller,
    required this.rotulo,
    required this.sufixo,
    this.obrigatorio = false,
    this.maiorQueZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: rotulo, suffixText: sufixo),
      validator: (v) {
        final texto = (v ?? '').trim();
        if (texto.isEmpty) return obrigatorio ? 'Obrigatório' : null;
        final n = double.tryParse(texto.replaceAll(',', '.'));
        if (n == null || n < 0) return 'Valor inválido';
        if (maiorQueZero && n <= 0) return 'Maior que zero';
        return null;
      },
    );
  }
}
