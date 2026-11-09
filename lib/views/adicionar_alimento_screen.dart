import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/novo_alimento_screen.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/quantidade_alimento_sheet.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

/// Busca de alimentos (base TACO + alimentos do usuário) para lançar numa refeição.
/// Dá para adicionar vários seguidos; retorna true se adicionou algum.
class AdicionarAlimentoScreen extends StatefulWidget {
  final DateTime dia;
  final Refeicao refeicao;

  const AdicionarAlimentoScreen({super.key, required this.dia, required this.refeicao});

  @override
  State<AdicionarAlimentoScreen> createState() => _AdicionarAlimentoScreenState();
}

class _AdicionarAlimentoScreenState extends State<AdicionarAlimentoScreen> {
  final _api = ApiService.instance;
  final _busca = TextEditingController();
  Timer? _atraso;
  late Future<List<Alimento>> _resultados = _api.buscarAlimentos(null);
  int _adicionados = 0;

  @override
  void dispose() {
    _atraso?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String _) {
    _atraso?.cancel();
    _atraso = Timer(const Duration(milliseconds: 300), _buscar);
    setState(() {});
  }

  void _buscar() {
    setState(() {
      _resultados = _api.buscarAlimentos(_busca.text);
    });
  }

  Future<void> _escolher(Alimento alimento) async {
    final escolha = await escolherQuantidade(context, alimento: alimento, refeicao: widget.refeicao);
    if (escolha is! QuantidadeEscolhida || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await _api.registrarAlimento(
        dia: widget.dia,
        refeicao: escolha.refeicao,
        alimentoId: alimento.id,
        gramas: escolha.gramas,
        rotuloPorcao: escolha.rotuloPorcao,
      );
      _adicionados++;
      mensageiro
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${alimento.nome} adicionado ao ${escolha.refeicao.rotulo.toLowerCase()}'),
          duration: const Duration(seconds: 2),
        ));
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      mensageiro.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _cadastrar() async {
    final novo = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(builder: (_) => NovoAlimentoScreen(nomeInicial: _busca.text.trim())),
    );
    if (novo != null && mounted) {
      _buscar();
      await _escolher(novo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final buscando = _busca.text.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.pop(context, _adicionados > 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.refeicao.rotulo),
          actions: [
            if (_adicionados > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: Text('Concluir ($_adicionados)'),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _busca,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _aoDigitar,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Buscar alimento (ex.: arroz, frango grelhado)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: buscando
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Limpar',
                          onPressed: () {
                            _busca.clear();
                            _buscar();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Alimento>>(
          future: _resultados,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EstadoVazio(
                icone: Icons.cloud_off_rounded,
                titulo: 'Não foi possível buscar',
                mensagem: snapshot.error.toString(),
                rotuloAcao: 'Tentar novamente',
                onAcao: _buscar,
              );
            }
            final itens = snapshot.data;
            if (itens == null) return const Center(child: CircularProgressIndicator());
            if (itens.isEmpty) {
              return EstadoVazio(
                icone: buscando ? Icons.search_off_rounded : Icons.restaurant_rounded,
                titulo: buscando ? 'Nada encontrado' : 'Busque um alimento',
                mensagem: buscando
                    ? 'Tente outra palavra ou cadastre o alimento com os dados do rótulo.'
                    : 'São mais de 600 alimentos da Tabela Brasileira de Composição de Alimentos (TACO). '
                        'Os que você usar aparecem aqui depois.',
                rotuloAcao: 'Cadastrar alimento',
                onAcao: _cadastrar,
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    buscando ? 'RESULTADOS' : 'USADOS RECENTEMENTE',
                    style: tema.textTheme.labelMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final alimento in itens)
                  ListTile(
                    title: Text(alimento.nome),
                    subtitle: Text(
                      [
                        '${formatarKcal(alimento.por100g.kcal)} kcal/100 g',
                        if (alimento.porcoes.isNotEmpty)
                          '${alimento.porcoes.first.rotulo} = ${formatarKcal(alimento.para(alimento.porcoes.first.gramas).kcal)} kcal',
                      ].join(' · '),
                    ),
                    leading: alimento.personalizado
                        ? Icon(Icons.person_outline_rounded, color: esquema.primary)
                        : null,
                    trailing: Icon(Icons.add_circle_outline_rounded, color: esquema.primary),
                    onTap: () => _escolher(alimento),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: _cadastrar,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Não achou? Cadastrar alimento'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
