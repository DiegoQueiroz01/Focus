import 'package:flutter/material.dart';
import 'package:focus/models/treino_model.dart';

class TreinoFormScreen extends StatefulWidget {
  const TreinoFormScreen({super.key});

  @override
  State<TreinoFormScreen> createState() => _TreinoFormScreenState();
}

class _TreinoFormScreenState extends State<TreinoFormScreen> {
  final _sessaoController = TextEditingController();
  final List<Exercicio> _exercicioAdicionado = [];

  //Função para abrir uma nova janela de form
  void _abrirDialogExercicio() {
    final nomeExercicioController = TextEditingController();
    final seriesController = TextEditingController();

    showDialog(
      context: context, builder: (context) => AlertDialog(
        title: const Text('Novo Exercício'), content: Column(
          mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nomeExercicioController,
              decoration: const InputDecoration(labelText: 'Nome do Exercício'),
            ),
            TextField(
              controller: seriesController,
              decoration: const InputDecoration(labelText: 'Quantidade de Sérires'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _exercicioAdicionado.add(
                  Exercicio(
                    nome: nomeExercicioController.text,
                    series: int.parse(seriesController.text.isEmpty ? '0' : seriesController.text),
                  ),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _salvarTreino() {
    if (_sessaoController.text.isEmpty) {
      final novoTreino = Treino(
        sessao: _sessaoController.text,
        exercicios: _exercicioAdicionado,
      );
      Navigator.pop(context, novoTreino);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inserir Treino')),
      body: Padding(
        padding: const EdgeInsets.all(16.0), child: Column(
          children: [
            TextField(
              controller: _sessaoController,
              decoration: const InputDecoration(
                labelText: 'Nome da sessão',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _abrirDialogExercicio,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Exercício'),
            ),
            const Divider(),

            Expanded(
              child: ListView.builder(
                itemCount: _exercicioAdicionado.length,
                itemBuilder: (context, index) {
                  final ex = _exercicioAdicionado[index];
                  return ListTile(
                    title: Text(ex.nome),
                    subtitle: Text('${ex.series} séries'),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarTreino,
                child: const Text('Salvar sessão de Treino'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}