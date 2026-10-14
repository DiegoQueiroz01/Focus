import 'package:flutter/material.dart';
import '../models/treino_model.dart';
import 'package:focus/service/json_service.dart';
import 'treino_form_screen.dart';
import 'package:focus/views/treinos_detalhes_screen.dart';

class TreinoScreen extends StatefulWidget {
  const TreinoScreen({super.key});

  @override
  State<TreinoScreen> createState() => _TreinoScreenState();
}

class _TreinoScreenState extends State<TreinoScreen> {
  final List<Treino> _meusTreinos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarTreinosJson();
  }

  void _carregarTreinosJson() async {
    final jsonService = JsonService();
    final dados = await jsonService.lerTreinos();
    setState(() {
      _meusTreinos.clear();
      for (var item in dados) {
        _meusTreinos.add(Treino.fromJson(item));
      }
      _carregando = false;
    });
  }

  void _irParaFormulario() async {
    final Treino? novoTreino = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TreinoFormScreen()),
    );

    if (novoTreino != null) {
      setState(() {
        _meusTreinos.add(novoTreino);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Treinos')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _meusTreinos.isEmpty
              ? const Center(child: Text('Nenhum treino encontrado.'))
              : ListView.builder(
                  itemCount: _meusTreinos.length,
                  itemBuilder: (context, index) {
                    final treino = _meusTreinos[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center, color: Colors.blue),
                        title: Text(treino.nomeSessao, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${treino.exercicios.length} exercícios cadastrados'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TreinoDetalhesScreen(treino: treino),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irParaFormulario,
        child: const Icon(Icons.add),
      ),
    );
  }
}