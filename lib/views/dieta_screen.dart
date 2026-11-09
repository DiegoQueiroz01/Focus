import 'package:flutter/material.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/adicionar_alimento_screen.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/views/meta_dieta_screen.dart';
import 'package:focus/views/peso_screen.dart';
import 'package:focus/views/questionario_dieta_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/quantidade_alimento_sheet.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

typedef _Dados = (PerfilNutricional, DiaDieta);

/// Seção "Dieta": meta do dia, calorias e macros consumidos e as refeições.
/// No primeiro acesso, convida a responder o questionário que calcula a meta.
class DietaScreen extends StatefulWidget {
  const DietaScreen({super.key});

  @override
  State<DietaScreen> createState() => _DietaScreenState();
}

class _DietaScreenState extends State<DietaScreen> {
  final _api = ApiService.instance;
  DateTime _dia = inicioDoDia(DateTime.now());
  late Future<_Dados> _dados = _carregar();

  Future<_Dados> _carregar() async {
    final resultados = await Future.wait([_api.getPerfil(), _api.getDiaDieta(_dia)]);
    return (resultados[0] as PerfilNutricional, resultados[1] as DiaDieta);
  }

  Future<void> _recarregar() async {
    final novo = _carregar();
    setState(() {
      _dados = novo;
    });
    await novo.then((_) {}, onError: (_) {});
  }

  void _mudarDia(int dias) {
    final novo = DateTime(_dia.year, _dia.month, _dia.day + dias);
    if (novo.isAfter(inicioDoDia(DateTime.now()))) return;
    _dia = novo;
    _recarregar();
  }

  Future<void> _abrirQuestionario(PerfilNutricional? perfil) async {
    final salvo = await Navigator.of(context).push<PerfilNutricional>(
      MaterialPageRoute(builder: (_) => QuestionarioDietaScreen(perfil: perfil)),
    );
    if (salvo == null || !mounted) return;
    await _recarregar();
    if (mounted) await _abrirMeta(salvo, recemCalculada: true);
  }

  Future<void> _abrirMeta(PerfilNutricional perfil, {bool recemCalculada = false}) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MetaDietaScreen(perfil: perfil, recemCalculada: recemCalculada)),
    );
    if (!mounted) return;
    await _recarregar();
    if (resultado == MetaDietaScreen.refazer && mounted) await _abrirQuestionario(perfil);
  }

  Future<void> _adicionar(Refeicao refeicao) async {
    final adicionou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdicionarAlimentoScreen(dia: _dia, refeicao: refeicao)),
    );
    if (adicionou == true && mounted) await _recarregar();
  }

  Future<void> _editar(RegistroAlimento registro) async {
    Alimento alimento;
    try {
      alimento = await _api.getAlimento(registro.alimentoId);
    } on ApiException {
      // Alimento personalizado apagado: edita só em gramas, com os valores guardados no registro.
      final fator = registro.gramas <= 0 ? 0.0 : 100 / registro.gramas;
      alimento = Alimento(
        id: registro.alimentoId,
        nome: registro.nome,
        categoria: '',
        origem: 'custom',
        por100g: registro.totais.vezes(fator),
      );
    }
    if (!mounted) return;
    final escolha = await escolherQuantidade(context, alimento: alimento, refeicao: registro.refeicao, registro: registro);
    if (escolha == null || !mounted) return;
    try {
      switch (escolha) {
        case ExcluirRegistro():
          await _api.excluirRegistroAlimento(registro.id);
        case QuantidadeEscolhida(:final refeicao, :final gramas, :final rotuloPorcao):
          await _api.atualizarRegistroAlimento(registro.id, refeicao: refeicao, gramas: gramas, rotuloPorcao: rotuloPorcao);
      }
      await _recarregar();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _abrirPeso() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PesoScreen()));
    if (mounted) await _recarregar();
  }

  Future<void> _registrarPeso(double? atual) async {
    if (await registrarPeso(context, atual: atual) && mounted) await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return FutureBuilder<_Dados>(
      future: _dados,
      builder: (context, snapshot) {
        final dados = snapshot.data;
        final perfil = dados?.$1;
        final completo = perfil?.completo == true;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            leading: const BotaoMenu(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dieta', style: tema.textTheme.headlineSmall),
                Text(
                  'Calorias, macros e refeições',
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              if (completo)
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Minha meta',
                  onPressed: () => _abrirMeta(perfil!),
                ),
            ],
          ),
          body: Builder(
            builder: (context) {
              if (snapshot.hasError) {
                return EstadoVazio(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não foi possível carregar',
                  mensagem: snapshot.error.toString(),
                  rotuloAcao: 'Tentar novamente',
                  onAcao: _recarregar,
                );
              }
              if (dados == null) return const Center(child: CircularProgressIndicator());
              if (!completo) return _BoasVindas(onComecar: () => _abrirQuestionario(perfil));
              return _conteudo(perfil!, dados.$2);
            },
          ),
        );
      },
    );
  }

  Widget _conteudo(PerfilNutricional perfil, DiaDieta dia) {
    final plano = dia.plano ?? perfil.plano!;
    final hoje = inicioDoDia(DateTime.now());

    return RefreshIndicator(
      onRefresh: _recarregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _SeletorDia(
            dia: _dia,
            podeAvancar: _dia.isBefore(hoje),
            onAnterior: () => _mudarDia(-1),
            onProximo: () => _mudarDia(1),
            onHoje: _dia == hoje
                ? null
                : () {
                    _dia = hoje;
                    _recarregar();
                  },
          ),
          const SizedBox(height: 8),
          _ResumoDoDia(plano: plano, totais: dia.totais),
          const SizedBox(height: 12),
          _CartaoPeso(
            perfil: perfil,
            onAbrir: _abrirPeso,
            onRegistrar: () => _registrarPeso(perfil.pesoKg),
          ),
          const SizedBox(height: 20),
          for (final refeicao in dia.refeicoes) ...[
            _CartaoRefeicao(
              refeicao: refeicao,
              onAdicionar: () => _adicionar(refeicao.refeicao),
              onEditar: _editar,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BoasVindas extends StatelessWidget {
  final VoidCallback onComecar;

  const _BoasVindas({required this.onComecar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    Widget item(IconData icone, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: esquema.primary.withValues(alpha: 0.14),
                child: Icon(icone, size: 18, color: esquema.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(texto, style: tema.textTheme.bodyLarge)),
            ],
          ),
        );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.restaurant_menu_rounded, size: 56, color: esquema.primary),
              const SizedBox(height: 16),
              Text('Vamos montar sua meta', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Responda algumas perguntas rápidas (menos de 1 minuto) para calcularmos quanto você deve comer por dia.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              item(Icons.local_fire_department_rounded, 'Calorias por dia para emagrecer, manter ou ganhar massa'),
              item(Icons.pie_chart_outline_rounded, 'Gramas de proteína, carboidrato e gordura'),
              item(Icons.restaurant_rounded, 'Registro das refeições com mais de 600 alimentos brasileiros'),
              item(Icons.monitor_weight_outlined, 'Acompanhamento do seu peso'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onComecar, child: const Text('Começar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeletorDia extends StatelessWidget {
  final DateTime dia;
  final bool podeAvancar;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final VoidCallback? onHoje;

  const _SeletorDia({
    required this.dia,
    required this.podeAvancar,
    required this.onAnterior,
    required this.onProximo,
    this.onHoje,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final relativo = formatarDataRelativa(dia);
    return Row(
      children: [
        IconButton(onPressed: onAnterior, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Dia anterior'),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onHoje,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(relativo, style: tema.textTheme.titleMedium),
                  Text(
                    onHoje == null ? formatarDiaExtenso(dia) : 'Toque para voltar para hoje',
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: podeAvancar ? onProximo : null,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Próximo dia',
        ),
      ],
    );
  }
}

class _ResumoDoDia extends StatelessWidget {
  final PlanoNutricional plano;
  final Nutrientes totais;

  const _ResumoDoDia({required this.plano, required this.totais});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    Widget numero(String rotulo, String valor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
            Text(valor, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AnelCalorias(consumido: totais.kcal, meta: plano.calorias, tamanho: 140),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      numero('Meta', '${formatarKcal(plano.calorias)} kcal'),
                      const SizedBox(height: 12),
                      numero('Consumido', '${formatarKcal(totais.kcal)} kcal'),
                      const SizedBox(height: 12),
                      numero('Fibras', '${totais.fibra.round()} / ${plano.fibraG} g'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraMacro(
                    nome: 'Proteína',
                    consumido: totais.proteina,
                    meta: plano.proteinaG,
                    cor: CoresMacros.proteina,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: BarraMacro(
                    nome: 'Carboidratos',
                    consumido: totais.carboidrato,
                    meta: plano.carboidratoG,
                    cor: CoresMacros.carboidrato,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: BarraMacro(
                    nome: 'Gorduras',
                    consumido: totais.gordura,
                    meta: plano.gorduraG,
                    cor: CoresMacros.gordura,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoPeso extends StatelessWidget {
  final PerfilNutricional perfil;
  final VoidCallback onAbrir;
  final VoidCallback onRegistrar;

  const _CartaoPeso({required this.perfil, required this.onAbrir, required this.onRegistrar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final peso = perfil.pesoKg;
    final data = perfil.dataPeso;
    final meta = perfil.pesoMetaKg;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: esquema.primary.withValues(alpha: 0.14),
                child: Icon(Icons.monitor_weight_outlined, color: esquema.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peso == null ? 'Peso' : formatarPeso(peso), style: tema.textTheme.titleMedium),
                    Text(
                      [
                        if (data != null) 'Atualizado ${formatarDataRelativa(data).toLowerCase()}',
                        if (meta != null) 'meta ${formatarPeso(meta)}',
                      ].join(' · '),
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onRegistrar,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoRefeicao extends StatelessWidget {
  final RefeicaoDoDia refeicao;
  final VoidCallback onAdicionar;
  final ValueChanged<RegistroAlimento> onEditar;

  const _CartaoRefeicao({required this.refeicao, required this.onAdicionar, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final itens = refeicao.itens;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(refeicao.refeicao.icone, color: esquema.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(refeicao.refeicao.rotulo, style: tema.textTheme.titleMedium)),
                if (itens.isNotEmpty)
                  Text(
                    '${formatarKcal(refeicao.totais.kcal)} kcal',
                    style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                IconButton(
                  onPressed: onAdicionar,
                  icon: Icon(Icons.add_circle_rounded, color: esquema.primary),
                  tooltip: 'Adicionar ao ${refeicao.refeicao.rotulo.toLowerCase()}',
                ),
              ],
            ),
          ),
          if (itens.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 16, 14),
              child: Text(
                'Nada registrado',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            )
          else ...[
            for (final item in itens)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(48, 0, 16, 0),
                title: Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  item.rotuloPorcao == null
                      ? formatarGramas(item.gramas)
                      : '${item.rotuloPorcao} · ${formatarGramas(item.gramas)}',
                ),
                trailing: Text(
                  formatarKcal(item.totais.kcal),
                  style: tema.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                onTap: () => onEditar(item),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 4, 16, 12),
              child: LinhaMacros(
                proteina: refeicao.totais.proteina,
                carboidrato: refeicao.totais.carboidrato,
                gordura: refeicao.totais.gordura,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
