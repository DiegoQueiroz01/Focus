import 'package:flutter/material.dart';
import 'package:focus/config/api_config.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/treino_form_screen.dart';
import 'package:focus/views/treinos_detalhes_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/treino_tile.dart';

class TreinoScreen extends StatefulWidget {
  const TreinoScreen({super.key});

  @override
  State<TreinoScreen> createState() => _TreinoScreenState();
}

class _TreinoScreenState extends State<TreinoScreen> {
  /// Distância (px) do fim da lista em que a próxima página começa a carregar.
  static const _limiarCarregamento = 300.0;

  final _api = ApiService.instance;
  final ScrollController _scrollController = ScrollController();
  final List<Treino> _meusTreinos = [];

  bool _carregandoInicial = true;
  bool _carregandoMais = false;
  bool _temMais = true;
  int? _total;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_aoRolar);
    _carregarProximaPagina();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_aoRolar)
      ..dispose();
    super.dispose();
  }

  void _aoRolar() {
    final posicao = _scrollController.position;
    if (posicao.pixels >= posicao.maxScrollExtent - _limiarCarregamento) {
      _carregarProximaPagina();
    }
  }

  Future<void> _carregarProximaPagina() async {
    if (_carregandoMais || !_temMais) return;

    setState(() {
      _carregandoMais = true;
      _erro = null;
    });
    try {
      final pagina = await _api.getTreinos(
        offset: _meusTreinos.length,
        limit: ApiConfig.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _meusTreinos.addAll(pagina.itens);
        _temMais = pagina.temMais;
        _total = pagina.total;
      });
      // Se a primeira página não preencheu a tela, não haverá scroll para disparar a próxima.
      WidgetsBinding.instance.addPostFrameCallback((_) => _preencherTelaSeNecessario());
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) {
        setState(() {
          _carregandoMais = false;
          _carregandoInicial = false;
        });
      }
    }
  }

  void _preencherTelaSeNecessario() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) _carregarProximaPagina();
  }

  Future<void> _recarregar() async {
    setState(() {
      _meusTreinos.clear();
      _temMais = true;
    });
    await _carregarProximaPagina();
  }

  Future<void> _irParaFormulario() async {
    final Treino? novoTreino = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TreinoFormScreen()),
    );

    if (novoTreino != null) {
      // A lista é ordenada do mais recente para o mais antigo; o novo treino entra no topo.
      setState(() {
        _meusTreinos.insert(0, novoTreino);
        if (_total != null) _total = _total! + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Treinos', style: tema.textTheme.headlineSmall),
            if (_total != null)
              Text(
                '$_total ${_total == 1 ? 'sessão registrada' : 'sessões registradas'}',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: _construirCorpo(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irParaFormulario,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo treino'),
      ),
    );
  }

  Widget _construirCorpo() {
    if (_carregandoInicial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_meusTreinos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _recarregar,
        child: LayoutBuilder(
          builder: (context, restricoes) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: restricoes.maxHeight,
              child: _erro != null
                  ? EstadoVazio(
                      icone: Icons.cloud_off_rounded,
                      titulo: 'Não foi possível carregar',
                      mensagem: _erro,
                      rotuloAcao: 'Tentar novamente',
                      onAcao: _recarregar,
                    )
                  : const EstadoVazio(
                      icone: Icons.fitness_center_rounded,
                      titulo: 'Nenhum treino ainda',
                      mensagem: 'Toque em "Novo treino" para registrar sua primeira sessão.',
                    ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recarregar,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: _meusTreinos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _meusTreinos.length) return _rodapeDaLista();
          final treino = _meusTreinos[index];
          return TreinoTile(
            treino: treino,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TreinoDetalhesScreen(treino: treino)),
            ),
          );
        },
      ),
    );
  }

  Widget _rodapeDaLista() {
    if (_carregandoMais) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    if (_erro != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: TextButton.icon(
            onPressed: _carregarProximaPagina,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('$_erro Toque para tentar novamente.'),
          ),
        ),
      );
    }
    // Espaço para o FAB não cobrir o último item.
    return const SizedBox(height: 96);
  }
}
