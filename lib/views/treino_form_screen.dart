import 'package:flutter/material.dart';
import '../models/treino_model.dart';

class TreinoFormScreen extends StatefulWidget {
  const TreinoFormScreen({super.key});

  @override
  State<TreinoFormScreen> createState() => _TreinoFormScreenState();
}

class _TreinoFormScreenState extends State<TreinoFormScreen> {
  final _nomeSessaoController = TextEditingController();
  final List<Exercicio> _exerciciosAdicionados = [];

  void _abrirDialogExercicio() {
    final nomeExercicioController = TextEditingController();
    final seriesController = TextEditingController();
    final cargaController = TextEditingController();
    final repeticoesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Exercício'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeExercicioController,
                decoration: const InputDecoration(labelText: 'Nome do Exercício'),
              ),
              TextField(
                controller: seriesController,
                decoration: const InputDecoration(labelText: 'Número de Séries'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: cargaController,
                decoration: const InputDecoration(labelText: 'Carga (kg)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: repeticoesController,
                decoration: const InputDecoration(labelText: 'Repetições'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _exerciciosAdicionados.add(
                  Exercicio(
                    nome: nomeExercicioController.text,
                    series: int.tryParse(seriesController.text) ?? 0,
                    cargaKg: int.tryParse(cargaController.text) ?? 0,
                    repeticoes: int.tryParse(repeticoesController.text) ?? 0,
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
    if (_nomeSessaoController.text.isNotEmpty) {
      final novoTreino = Treino(
        nomeSessao: _nomeSessaoController.text,
        exercicios: _exerciciosAdicionados,
      );
      Navigator.pop(context, novoTreino);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inserir Treino')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeSessaoController,
              decoration: const InputDecoration(
                labelText: 'Nome da Sessão (Ex: Treino A)',
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
                itemCount: _exerciciosAdicionados.length,
                itemBuilder: (context, index) {
                  final ex = _exerciciosAdicionados[index];
                  return ListTile(
                    title: Text(ex.nome),
                    subtitle: Text('${ex.series} séries • ${ex.repeticoes} reps • ${ex.cargaKg} kg'),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarTreino,
                child: const Text('Salvar Sessão de Treino'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}