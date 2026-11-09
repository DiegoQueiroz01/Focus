import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/widgets/dialogo_padrao.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

/// Mostra a meta diária (calorias e macros) e explica de onde vieram os números.
/// Também deixa refazer o questionário ou definir as calorias manualmente.
class MetaDietaScreen extends StatefulWidget {
  final PerfilNutricional perfil;

  /// Logo depois do questionário: mostra o botão "Começar".
  final bool recemCalculada;

  const MetaDietaScreen({super.key, required this.perfil, this.recemCalculada = false});

  /// Resultado devolvido quando o usuário toca em "Refazer questionário".
  static const refazer = 'refazer';

  @override
  State<MetaDietaScreen> createState() => _MetaDietaScreenState();
}

class _MetaDietaScreenState extends State<MetaDietaScreen> {
  late PerfilNutricional _perfil = widget.perfil;
  bool _salvando = false;

  /// Fecha esta tela pedindo que a Dieta abra o questionário de novo.
  void _refazer() => Navigator.pop(context, MetaDietaScreen.refazer);

  Future<void> _definirCalorias(int? calorias) async {
    setState(() => _salvando = true);
    try {
      final perfil = await ApiService.instance.salvarPerfil(RespostasPerfil.comCalorias(_perfil, calorias));
      if (mounted) setState(() => _perfil = perfil);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _pedirCalorias() async {
    final controller = TextEditingController(text: '${_perfil.plano!.calorias}');
    final valor = await showDialog<int>(
      context: context,
      builder: (context) {
        void confirmar() {
          final n = int.tryParse(controller.text);
          if (n != null && n >= 800 && n <= 6000) Navigator.pop(context, n);
        }

        return DialogoPadrao(
          icone: Icons.tune_rounded,
          titulo: 'Calorias por dia',
          conteudo: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Use se um nutricionista passou uma meta. Os macros são redistribuídos automaticamente.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'kcal', helperText: 'Entre 800 e 6.000'),
                onSubmitted: (_) => confirmar(),
              ),
            ],
          ),
          rotuloPrincipal: 'Salvar',
          onPrincipal: confirmar,
          rotuloSecundario: 'Cancelar',
        );
      },
    );
    controller.dispose();
    if (valor != null) await _definirCalorias(valor);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final plano = _perfil.plano!;
    final objetivo = _perfil.objetivo!;
    final peso = _perfil.pesoKg!;

    final kcalProteina = plano.proteinaG * 4;
    final kcalCarbo = plano.carboidratoG * 4;
    final kcalGordura = plano.gorduraG * 9;
    final kcalMacros = (kcalProteina + kcalCarbo + kcalGordura).clamp(1, 100000);
    int pct(int kcal) => (kcal / kcalMacros * 100).round();
    String gKg(int g) => '${(g / peso).toStringAsFixed(1).replaceAll('.', ',')} g/kg';

    return Scaffold(
      appBar: AppBar(title: const Text('Minha meta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(objetivo.icone, color: esquema.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(objetivo.rotulo, style: tema.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    formatarKcal(plano.calorias),
                    style: tema.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: esquema.primary),
                  ),
                  Text('kcal por dia', style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                  if (plano.caloriasPersonalizadas) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Definida por você'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _LinhaMacro(nome: 'Proteína', gramas: plano.proteinaG, pct: pct(kcalProteina), detalhe: gKg(plano.proteinaG), cor: CoresMacros.proteina),
                  _LinhaMacro(nome: 'Carboidratos', gramas: plano.carboidratoG, pct: pct(kcalCarbo), detalhe: gKg(plano.carboidratoG), cor: CoresMacros.carboidrato),
                  _LinhaMacro(nome: 'Gorduras', gramas: plano.gorduraG, pct: pct(kcalGordura), detalhe: gKg(plano.gorduraG), cor: CoresMacros.gordura),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(flex: kcalProteina, child: const ColoredBox(color: CoresMacros.proteina)),
                          Expanded(flex: kcalCarbo, child: const ColoredBox(color: CoresMacros.carboidrato)),
                          Expanded(flex: kcalGordura, child: const ColoredBox(color: CoresMacros.gordura)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (plano.limitadoPeloMinimo) ...[
            const SizedBox(height: 12),
            _Aviso(
              icone: Icons.info_outline_rounded,
              texto: 'A conta daria menos que o mínimo seguro, então a meta foi elevada. '
                  'O emagrecimento será um pouco mais lento que o ritmo escolhido.',
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Como calculamos', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ItemConta(
                    rotulo: 'Gasto em repouso (TMB)',
                    valor: '${formatarKcal(plano.tmb)} kcal',
                    ajuda: 'Equação de Mifflin-St Jeor com seu sexo, idade (${_perfil.idade} anos), '
                        'altura (${_perfil.alturaCm!.round()} cm) e peso (${formatarPeso(peso)}).',
                  ),
                  _ItemConta(
                    rotulo: 'Gasto total por dia',
                    valor: '${formatarKcal(plano.gastoTotal)} kcal',
                    ajuda: 'TMB × fator de atividade (${_perfil.atividade!.rotulo.toLowerCase()}).',
                  ),
                  _ItemConta(
                    rotulo: plano.ajusteKcal < 0 ? 'Déficit' : (plano.ajusteKcal > 0 ? 'Superávit' : 'Ajuste'),
                    valor: '${plano.ajusteKcal > 0 ? '+' : ''}${formatarKcal(plano.ajusteKcal)} kcal',
                    ajuda: plano.variacaoSemanalKg == 0
                        ? 'Você come o mesmo que gasta para manter o peso.'
                        : 'Cerca de ${plano.variacaoSemanalKg.abs().toStringAsFixed(2).replaceAll('.', ',')} kg por semana '
                            '(1 kg de gordura ≈ 7.700 kcal).',
                  ),
                  if (plano.semanasAteMeta != null && _perfil.pesoMetaKg != null)
                    _ItemConta(
                      rotulo: 'Previsão até ${formatarPeso(_perfil.pesoMetaKg!)}',
                      valor: '~${plano.semanasAteMeta} semanas',
                      ajuda: 'Se mantiver a meta todos os dias. O peso varia dia a dia; olhe a tendência.',
                    ),
                  _ItemConta(
                    rotulo: 'Proteína',
                    valor: gKg(plano.proteinaG),
                    ajuda: objetivo == Objetivo.emagrecer
                        ? 'Mais alta no déficit para preservar músculo.'
                        : 'Faixa recomendada para quem treina (1,6 a 2,2 g/kg).',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Indicador(
                  icone: Icons.monitor_weight_outlined,
                  valor: plano.imc.toStringAsFixed(1).replaceAll('.', ','),
                  rotulo: 'IMC · ${plano.classificacaoImc}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Indicador(
                  icone: Icons.water_drop_outlined,
                  valor: '${(plano.aguaMl / 1000).toStringAsFixed(1).replaceAll('.', ',')} L',
                  rotulo: 'Água por dia',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Indicador(icone: Icons.grass_rounded, valor: '${plano.fibraG} g', rotulo: 'Fibras por dia'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Aviso(
            icone: Icons.health_and_safety_outlined,
            texto: 'Estes valores são estimativas para pessoas saudáveis. Gestantes, pessoas com doenças '
                'ou em uso de medicamentos devem seguir a orientação de um nutricionista ou médico.',
          ),
          const SizedBox(height: 24),
          if (widget.recemCalculada) ...[
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.restaurant_rounded),
              label: const Text('Começar a registrar'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _salvando ? null : _refazer,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refazer questionário'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salvando
                ? null
                : (plano.caloriasPersonalizadas ? () => _definirCalorias(null) : _pedirCalorias),
            icon: Icon(plano.caloriasPersonalizadas ? Icons.calculate_outlined : Icons.tune_rounded),
            label: Text(plano.caloriasPersonalizadas ? 'Voltar para a meta calculada' : 'Definir calorias manualmente'),
          ),
        ],
      ),
    );
  }
}

class _LinhaMacro extends StatelessWidget {
  final String nome;
  final int gramas;
  final int pct;
  final String detalhe;
  final Color cor;

  const _LinhaMacro({required this.nome, required this.gramas, required this.pct, required this.detalhe, required this.cor});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Flexible(
            flex: 3,
            child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodyLarge),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$detalhe · $pct%',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall?.copyWith(color: secundario),
              ),
            ),
          ),
          Text('$gramas g', style: tema.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ItemConta extends StatelessWidget {
  final String rotulo;
  final String valor;
  final String ajuda;

  const _ItemConta({required this.rotulo, required this.valor, required this.ajuda});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rotulo, style: tema.textTheme.bodyLarge)),
              Text(valor, style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text(ajuda, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String rotulo;

  const _Indicador({required this.icone, required this.valor, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 20, color: tema.colorScheme.primary),
            const SizedBox(height: 8),
            Text(valor, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              rotulo,
              maxLines: 2,
              style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Aviso({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: esquema.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
