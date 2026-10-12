import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _indiceAtual = 0; //controla a barra de navegação inferior da tela

  //função para a barra inferior
  void _aoTocarNaBarra(int index){
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha evolução'),
        centerTitle: true,
      ),

      //Seção de resumo da semana
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo da semana', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded( child: Card( elevation: 4, child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: const [
                      Icon(Icons.timer, size:40, color: Colors.blue),
                      SizedBox(height: 8),
                      Text('Tempo Total: ', style: TextStyle(color: Colors.grey)),
                      Text('4h 30m', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ),
                ),
                const SizedBox(width: 16),

                // Séries totais
                Expanded(
                  child: Card( elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: const [
                        Icon(Icons.fitness_center, size:40, color: Colors.orange),
                        SizedBox(height: 8),
                        Text('Séries Totais: ', style: TextStyle(color: Colors.grey)),
                        Text('85', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            //Histórico
            const Text('Últimas Atividades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.blue),
                title: const Text('Treino A - Peito e Tríceps'),
                subtitle: const Text('Treino da segunda-feira'),
                trailing: const Text('1h 10m'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_bike, color: Colors.green),
                title: const Text('Cardio em bicicleta (Casa)'),
                subtitle: const Text('Cardio da quarta-feira'),
                trailing: const Text('30m - 10 Km - Pace: 3:00'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_run, color: Colors.orange),
                title: const Text('Corrida leve'),
                subtitle: const Text('Cardio da segunda-feira'),
                trailing: const Text('30m - 3 Km - Pace 10:00'),
              ),
            ),
          ],
        ),
      ),

      //Barra de navegação
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: _aoTocarNaBarra,
        items: const[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Treino',
          ),
        ],
      ),
    );
  }
}