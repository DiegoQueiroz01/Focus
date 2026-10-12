import 'package:flutter/material.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/views/treino_form_screen.dart';

class TreinoScreen extends StatefulWidget {
  const TreinoScreen({super.key});

  @override
  State<TreinoScreen> createState() => _TreinoScreenState();
}

class _TreinoScreenState extends State<TreinoScreen> {
  final List<Treino> _meusTreinos = [];

  void _irParaFormulario() async {
    final Treino ? novoTreino = await Navigator.push(
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
      body: ListView.builder(
        itemCount: _meusTreinos.length,
        itemBuilder: (context, index) {
          final treino = _meusTreinos[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(treino.sessao, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${treino.exercicios.length} exercícios cadastrados'),
              onTap: () {
                
                print('Clicou no treino: ${treino.sessao}');
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