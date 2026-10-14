import 'package:flutter/material.dart';
import '../models/treino_model.dart';

class TreinoDetalhesScreen extends StatelessWidget {
  final Treino treino;

  const TreinoDetalhesScreen({super.key, required this.treino});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(treino.nomeSessao),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo: ${treino.tipo}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (treino.data.isNotEmpty)
              Text(
                'Data: ${treino.data}',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            const Text(
              'Exercícios e Cargas:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: treino.exercicios.isEmpty
                  ? const Center(child: Text('Nenhum exercício registrado nesta sessão.'))
                  : ListView.builder(
                      itemCount: treino.exercicios.length,
                      itemBuilder: (context, index) {
                        final ex = treino.exercicios[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            leading: const Icon(Icons.fitness_center, color: Colors.blue),
                            title: Text(ex.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${ex.series} séries • ${ex.repeticoes > 0 ? "${ex.repeticoes} reps • " : ""}${ex.cargaKg} kg'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}