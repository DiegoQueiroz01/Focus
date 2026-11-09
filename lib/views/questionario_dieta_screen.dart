import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';

/// Perguntas para calcular a meta de calorias e macros. Abre sozinho no primeiro acesso
/// à Dieta e pode ser refeito a qualquer momento (vem preenchido com o perfil atual).
/// Ao terminar, salva e retorna o perfil com o plano calculado.
class QuestionarioDietaScreen extends StatefulWidget {
  final PerfilNutricional? perfil;

  const QuestionarioDietaScreen({super.key, this.perfil});

  @override
  State<QuestionarioDietaScreen> createState() => _QuestionarioDietaScreenState();
}

enum _Etapa { sexo, nascimento, medidas, atividade, objetivo, ritmo }

class _QuestionarioDietaScreenState extends State<QuestionarioDietaScreen> {
  late final PerfilNutricional? _p = widget.perfil;

  late Sexo? _sexo = _p?.sexo;
  late NivelAtividade? _atividade = _p?.atividade;
  late Objetivo? _objetivo = _p?.objetivo;
  late Ritmo _ritmo = _p?.ritmo ?? Ritmo.moderado;

  late final _nascimento = TextEditingController(text: _p?.nascimento == null ? '' : _formatarData(_p!.nascimento!));
  late final _altura = TextEditingController(text: _numero(_p?.alturaCm));
  late final _peso = TextEditingController(text: _numero(_p?.pesoKg));
  late final _pesoMeta = TextEditingController(text: _numero(_p?.pesoMetaKg));

  int _indice = 0;
  bool _salvando = false;
  String? _erro;

  static String _numero(double? v) {
    if (v == null) return '';
    return (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1)).replaceAll('.', ',');
  }

  static String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static double? _lerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  static DateTime? _lerData(String texto) {
    final partes = texto.split('/');
    if (partes.length != 3 || partes[2].length != 4) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);
    if (dia == null || mes == null || ano == null) return null;
    final data = DateTime(ano, mes, dia);
    // DateTime aceita 31/02 e "rola" para março; aqui isso é data inválida.
    return data.day == dia && data.month == mes ? data : null;
  }

  static int _idade(DateTime nascimento, DateTime hoje) {
    final antesDoAniversario =
        hoje.month < nascimento.month || (hoje.month == nascimento.month && hoje.day < nascimento.day);
    return hoje.year - nascimento.year - (antesDoAniversario ? 1 : 0);
  }

  List<_Etapa> get _etapas => [
        _Etapa.sexo,
        _Etapa.nascimento,
        _Etapa.medidas,
        _Etapa.atividade,
        _Etapa.objetivo,
        if (_objetivo != Objetivo.manter) _Etapa.ritmo,
      ];

  _Etapa get _etapa => _etapas[_indice];
  bool get _ultima => _indice == _etapas.length - 1;

  @override
  void dispose() {
    _nascimento.dispose();
    _altura.dispose();
    _peso.dispose();
    _pesoMeta.dispose();
    super.dispose();
  }

  /// Mensagem de erro da etapa atual, ou null se dá para seguir.
  String? _validar() {
    switch (_etapa) {
      case _Etapa.sexo:
        return _sexo == null ? 'Escolha uma opção.' : null;
      case _Etapa.nascimento:
        final data = _lerData(_nascimento.text);
        if (data == null) return 'Informe a data no formato DD/MM/AAAA.';
        final idade = _idade(data, DateTime.now());
        if (idade < 13 || idade > 100) return 'A idade precisa estar entre 13 e 100 anos.';
        return null;
      case _Etapa.medidas:
        final altura = _lerNumero(_altura.text);
        final peso = _lerNumero(_peso.text);
        if (altura == null || altura < 100 || altura > 250) return 'Informe a altura em centímetros (ex.: 175).';
        if (peso == null || peso < 30 || peso > 300) return 'Informe o peso em kg (ex.: 72,5).';
        return null;
      case _Etapa.atividade:
        return _atividade == null ? 'Escolha seu nível de atividade.' : null;
      case _Etapa.objetivo:
        return _objetivo == null ? 'Escolha seu objetivo.' : null;
      case _Etapa.ritmo:
        final texto = _pesoMeta.text.trim();
        if (texto.isEmpty) return null;
        final meta = _lerNumero(texto);
        final atual = _lerNumero(_peso.text)!;
        if (meta == null || meta < 30 || meta > 300) return 'Peso desejado inválido.';
        if (_objetivo == Objetivo.emagrecer && meta >= atual) return 'Para emagrecer, o peso desejado deve ser menor que o atual.';
        if (_objetivo == Objetivo.ganhar && meta <= atual) return 'Para ganhar massa, o peso desejado deve ser maior que o atual.';
        return null;
    }
  }

  Future<void> _avancar() async {
    FocusScope.of(context).unfocus();
    final erro = _validar();
    setState(() => _erro = erro);
    if (erro != null) return;
    if (!_ultima) {
      setState(() => _indice++);
      return;
    }
    await _salvar();
  }

  void _voltar() {
    if (_indice == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _indice--;
        _erro = null;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final manter = _objetivo == Objetivo.manter;
    final respostas = RespostasPerfil(
      sexo: _sexo!,
      nascimento: _lerData(_nascimento.text)!,
      alturaCm: _lerNumero(_altura.text)!,
      pesoKg: _lerNumero(_peso.text)!,
      atividade: _atividade!,
      objetivo: _objetivo!,
      ritmo: manter ? null : _ritmo,
      pesoMetaKg: manter ? null : _lerNumero(_pesoMeta.text),
      // Refazer o questionário volta para as calorias calculadas.
      caloriasManuais: null,
    );
    try {
      final perfil = await ApiService.instance.salvarPerfil(respostas);
      if (mounted) Navigator.pop(context, perfil);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final total = _etapas.length;

    return PopScope(
      canPop: _indice == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _voltar();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _voltar),
          title: Text('Sua meta · ${_indice + 1} de $total'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_indice + 1) / total),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: esquema.surfaceContainer,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: SingleChildScrollView(
                    key: ValueKey(_etapa),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: _conteudo(tema),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_erro != null) ...[
                      Text(_erro!, textAlign: TextAlign.center, style: TextStyle(color: esquema.error)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _salvando ? null : _avancar,
                      child: _salvando
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_ultima ? 'Calcular minha meta' : 'Continuar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo(ThemeData tema) {
    switch (_etapa) {
      case _Etapa.sexo:
        return _Pergunta(
          titulo: 'Qual é o seu sexo biológico?',
          ajuda: 'Homens e mulheres gastam energia de forma diferente em repouso; isso entra no cálculo.',
          children: [
            for (final s in Sexo.values)
              _Opcao(
                icone: s.icone,
                titulo: s.rotulo,
                selecionada: _sexo == s,
                onTap: () => setState(() {
                  _sexo = s;
                  _erro = null;
                }),
              ),
          ],
        );
      case _Etapa.nascimento:
        final data = _lerData(_nascimento.text);
        final idade = data == null ? null : _idade(data, DateTime.now());
        return _Pergunta(
          titulo: 'Quando você nasceu?',
          ajuda: 'O gasto de energia diminui com a idade.',
          children: [
            TextField(
              controller: _nascimento,
              keyboardType: TextInputType.number,
              autofocus: _nascimento.text.isEmpty,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MascaraData()],
              decoration: InputDecoration(
                labelText: 'Data de nascimento',
                hintText: 'DD/MM/AAAA',
                prefixIcon: const Icon(Icons.cake_outlined),
                helperText: idade != null && idade > 0 ? '$idade anos' : null,
              ),
              onChanged: (_) => setState(() => _erro = null),
              onSubmitted: (_) => _avancar(),
            ),
          ],
        );
      case _Etapa.medidas:
        return _Pergunta(
          titulo: 'Sua altura e seu peso atual',
          ajuda: 'O peso fica salvo no seu perfil e é usado no app todo, inclusive nas calorias do GPS.',
          children: [
            _CampoNumero(controller: _altura, rotulo: 'Altura', sufixo: 'cm', icone: Icons.height_rounded, decimal: false),
            const SizedBox(height: 16),
            _CampoNumero(
              controller: _peso,
              rotulo: 'Peso atual',
              sufixo: 'kg',
              icone: Icons.monitor_weight_outlined,
              onSubmitted: _avancar,
            ),
          ],
        );
      case _Etapa.atividade:
        return _Pergunta(
          titulo: 'Quão ativo você é?',
          ajuda: 'Pense na sua rotina média, somando trabalho e treinos.',
          children: [
            for (final n in NivelAtividade.values)
              _Opcao(
                icone: n.icone,
                titulo: n.rotulo,
                descricao: n.descricao,
                selecionada: _atividade == n,
                onTap: () => setState(() {
                  _atividade = n;
                  _erro = null;
                }),
              ),
          ],
        );
      case _Etapa.objetivo:
        return _Pergunta(
          titulo: 'Qual é o seu objetivo?',
          children: [
            for (final o in Objetivo.values)
              _Opcao(
                icone: o.icone,
                titulo: o.rotulo,
                descricao: o.descricao,
                selecionada: _objetivo == o,
                onTap: () => setState(() {
                  _objetivo = o;
                  _erro = null;
                }),
              ),
          ],
        );
      case _Etapa.ritmo:
        final emagrecer = _objetivo == Objetivo.emagrecer;
        return _Pergunta(
          titulo: emagrecer ? 'Em que ritmo quer emagrecer?' : 'Em que ritmo quer ganhar massa?',
          ajuda: emagrecer
              ? 'Ritmos mais lentos são mais fáceis de manter e preservam mais músculo.'
              : 'Ganhar devagar ajuda a ganhar mais músculo e menos gordura.',
          children: [
            for (final r in Ritmo.values)
              _Opcao(
                icone: switch (r) {
                  Ritmo.lento => Icons.speed_rounded,
                  Ritmo.moderado => Icons.directions_walk_rounded,
                  Ritmo.rapido => Icons.directions_run_rounded,
                },
                titulo: r.rotulo,
                descricao:
                    '${emagrecer ? '-' : '+'}${r.kgPorSemana(_objetivo!).toString().replaceAll('.', ',')} kg por semana'
                    '${r == Ritmo.moderado ? ' · recomendado' : ''}',
                selecionada: _ritmo == r,
                onTap: () => setState(() => _ritmo = r),
              ),
            const SizedBox(height: 16),
            _CampoNumero(
              controller: _pesoMeta,
              rotulo: 'Peso desejado (opcional)',
              sufixo: 'kg',
              icone: Icons.flag_outlined,
              onSubmitted: _avancar,
            ),
          ],
        );
    }
  }
}

class _Pergunta extends StatelessWidget {
  final String titulo;
  final String? ajuda;
  final List<Widget> children;

  const _Pergunta({required this.titulo, this.ajuda, required this.children});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: tema.textTheme.headlineSmall),
        if (ajuda != null) ...[
          const SizedBox(height: 8),
          Text(ajuda!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _Opcao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? descricao;
  final bool selecionada;
  final VoidCallback onTap;

  const _Opcao({required this.icone, required this.titulo, this.descricao, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selecionada,
        button: true,
        child: Material(
          color: selecionada ? esquema.primary.withValues(alpha: 0.12) : esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selecionada ? esquema.primary : esquema.outlineVariant, width: selecionada ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icone, color: selecionada ? esquema.primary : esquema.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: tema.textTheme.titleMedium),
                        if (descricao != null)
                          Text(
                            descricao!,
                            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (selecionada) Icon(Icons.check_circle_rounded, color: esquema.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampoNumero extends StatelessWidget {
  final TextEditingController controller;
  final String rotulo;
  final String sufixo;
  final IconData icone;
  final bool decimal;
  final VoidCallback? onSubmitted;

  const _CampoNumero({
    required this.controller,
    required this.rotulo,
    required this.sufixo,
    required this.icone,
    this.decimal = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(labelText: rotulo, suffixText: sufixo, prefixIcon: Icon(icone)),
    );
  }
}

/// Insere as barras enquanto o usuário digita: 01011995 → 01/01/1995.
class _MascaraData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final digitos = novo.text.length > 8 ? novo.text.substring(0, 8) : novo.text;
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digitos[i]);
    }
    final texto = buffer.toString();
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
