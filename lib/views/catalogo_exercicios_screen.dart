import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focus/models/catalogo_exercicio.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/exercicio_catalogo_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/imagem_exercicio.dart';

/// O que o usuário escolheu no catálogo.
sealed class EscolhaCatalogo {
  const EscolhaCatalogo();
}

class ExercicioEscolhido extends EscolhaCatalogo {
  final CatalogoExercicio exercicio;

  const ExercicioEscolhido(this.exercicio);
}

/// Não achou o que queria e vai cadastrar à mão (com o texto da busca como nome).
class ExercicioPersonalizado extends EscolhaCatalogo {
  final String nome;

  const ExercicioPersonalizado(this.nome);
}

/// Lista de exercícios prontos com foto, busca, abas por tipo e filtro por grupo muscular.
class CatalogoExerciciosScreen extends StatefulWidget {
  final TipoTreino tipoInicial;

  const CatalogoExerciciosScreen({super.key, this.tipoInicial = TipoTreino.musculacao});

  @override
  State<CatalogoExerciciosScreen> createState() => _CatalogoExerciciosScreenState();
}

class _CatalogoExerciciosScreenState extends State<CatalogoExerciciosScreen> {
  static const _limiarCarregamento = 400.0;

  final _api = ApiService.instance;
  final _buscaController = TextEditingController();
  final _scrollController = ScrollController();
  final List<CatalogoExercicio> _itens = [];
  Timer? _atrasoBusca;

  late TipoTreino _tipo = widget.tipoInicial;
  GrupoMuscular? _grupo;
  int? _total;
  bool _carregando = false;
  bool _temMais = true;
  String? _erro;

  /// Cada nova consulta incrementa; respostas de consultas antigas são descartadas.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_aoRolar);
    _recarregar();
  }

  @override
  void dispose() {
    _atrasoBusca?.cancel();
    _buscaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _aoRolar() {
    final posicao = _scrollController.position;
    if (posicao.pixels >= posicao.maxScrollExtent - _limiarCarregamento) _carregarMais();
  }

  void _aoDigitar(String _) {
    _atrasoBusca?.cancel();
    _atrasoBusca = Timer(const Duration(milliseconds: 350), _recarregar);
    setState(() {}); // atualiza o botão de limpar
  }

  void _recarregar() {
    _consulta++;
    setState(() {
      _itens.clear();
      _temMais = true;
      _total = null;
      _carregando = false;
      _erro = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _carregarMais();
  }

  Future<void> _carregarMais() async {
    if (_carregando || !_temMais) return;
    final consulta = _consulta;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final pagina = await _api.getCatalogo(
        busca: _buscaController.text,
        tipo: _tipo,
        grupo: _tipo == TipoTreino.musculacao ? _grupo : null,
        offset: _itens.length,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _itens.addAll(pagina.itens);
        _temMais = pagina.temMais;
        _total = pagina.total;
      });
    } on ApiException catch (e) {
      if (mounted && consulta == _consulta) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _carregando = false);
    }
  }

  void _trocarTipo(TipoTreino tipo) {
    if (tipo == _tipo) return;
    _tipo = tipo;
    _grupo = null;
    _recarregar();
  }

  void _trocarGrupo(GrupoMuscular? grupo) {
    if (grupo == _grupo) return;
    _grupo = grupo;
    _recarregar();
  }

  Future<void> _abrirDetalhe(CatalogoExercicio item) async {
    final escolhido = await Navigator.push<CatalogoExercicio>(
      context,
      MaterialPageRoute(
        builder: (_) => ExercicioCatalogoScreen(id: item.id, resumo: item, podeAdicionar: true),
      ),
    );
    if (escolhido != null && mounted) Navigator.pop(context, ExercicioEscolhido(escolhido));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher exercício'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _buscaController,
              onChanged: _aoDigitar,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar exercício',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _buscaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _buscaController.clear();
                          _recarregar();
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<TipoTreino>(
                showSelectedIcon: false,
                segments: [
                  for (final tipo in TipoTreino.values) ButtonSegment(value: tipo, label: Text(tipo.rotulo)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => _trocarTipo(s.first),
              ),
            ),
          ),
          if (_tipo == TipoTreino.musculacao)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                children: [
                  _ChipGrupo(rotulo: 'Todos', selecionado: _grupo == null, onTap: () => _trocarGrupo(null)),
                  for (final grupo in GrupoMuscular.filtroMusculacao)
                    _ChipGrupo(rotulo: grupo.rotulo, selecionado: _grupo == grupo, onTap: () => _trocarGrupo(grupo)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _total == null ? ' ' : '$_total ${_total == 1 ? 'exercício' : 'exercícios'}',
                style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_itens.isEmpty && _carregando) return const Center(child: CircularProgressIndicator());
    if (_itens.isEmpty && _erro != null) {
      return EstadoVazio(
        icone: Icons.cloud_off_rounded,
        titulo: 'Não foi possível carregar',
        mensagem: _erro,
        rotuloAcao: 'Tentar novamente',
        onAcao: _recarregar,
      );
    }

    final busca = _buscaController.text.trim();
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _itens.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i < _itens.length) {
          final item = _itens[i];
          return _ItemCatalogo(
            item: item,
            onTap: () => _abrirDetalhe(item),
            onAdicionar: () => Navigator.pop(context, ExercicioEscolhido(item)),
          );
        }
        // Rodapé: carregando mais, erro, ou a opção de criar um exercício próprio.
        if (_carregando) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
          );
        }
        if (_erro != null) {
          return TextButton.icon(
            onPressed: _carregarMais,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('$_erro Toque para tentar novamente.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              if (_itens.isEmpty)
                const EstadoVazio(
                  icone: Icons.search_off_rounded,
                  titulo: 'Nenhum exercício encontrado',
                  mensagem: 'Tente outro nome ou crie o seu exercício.',
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ExercicioPersonalizado(busca)),
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(busca.isEmpty ? 'Criar exercício personalizado' : 'Criar "$busca"'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChipGrupo extends StatelessWidget {
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipGrupo({required this.rotulo, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: selecionado,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ItemCatalogo extends StatelessWidget {
  final CatalogoExercicio item;
  final VoidCallback onTap;
  final VoidCallback onAdicionar;

  const _ItemCatalogo({required this.item, required this.onTap, required this.onAdicionar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    final detalhes = [
      if (item.musculosPrincipais.isNotEmpty) item.resumoMusculos,
      if (item.equipamento != null) item.equipamento!,
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ImagemExercicio(url: item.imagemUrl, icone: item.icone, largura: 72, altura: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      detalhes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: secundario),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Adicionar ao treino',
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: tema.colorScheme.primary,
                onPressed: onAdicionar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
