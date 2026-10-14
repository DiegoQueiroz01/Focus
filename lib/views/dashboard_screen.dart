import 'package:flutter/material.dart';
import 'package:focus/views/treinos_screen.dart';
import 'package:focus/views/login_screen.dart';
import 'package:focus/service/json_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _indiceAtual = 0;

  final List<Widget> _telas = [
    const PainelResumo(),
    const TreinoScreen(),
  ];

  void _aoTocarNaBarra(int index) {
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_indiceAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: _aoTocarNaBarra,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Treinos',
          ),
        ],
      ),
    );
  }
}

class PainelResumo extends StatefulWidget {
  const PainelResumo({super.key});

  @override
  State<PainelResumo> createState() => _PainelResumoState();
}

class _PainelResumoState extends State<PainelResumo> {
  List<dynamic> _historico = [];
  int _tempoTotalMinutos = 0;
  int _seriesTotais = 0;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() async {
    final jsonService = JsonService();
    final dados = await jsonService.lerTreinos();
    
    int tempo = 0;
    int series = 0;

    for (var item in dados) {
      if (item is Map) {
        tempo += (item['tempoTotalMinutos'] as num? ?? 0).toInt();
        series += (item['seriesTotais'] as num? ?? 0).toInt();
      }
    }

    setState(() {
      _historico = dados;
      _tempoTotalMinutos = tempo;
      _seriesTotais = series;
      _carregando = false;
    });
  }

  void _fazerLogoff() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  String _formatarTempo(int minutos) {
    int horas = minutos ~/ 60;
    int mins = minutos % 60;
    if (horas > 0) {
      return '${horas}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Progresso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _fazerLogoff,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo da semana',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Icon(Icons.timer, size: 40, color: Colors.blue),
                                const SizedBox(height: 8),
                                const Text('Tempo Total: ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  _formatarTempo(_tempoTotalMinutos),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Icon(Icons.fitness_center, size: 40, color: Colors.orange),
                                const SizedBox(height: 8),
                                const Text('Séries Totais: ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  '$_seriesTotais',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Últimas Atividades',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._historico.map((item) {
                    IconData icone = Icons.fitness_center;
                    Color cor = Colors.blue;

                    String tipo = (item['tipo'] ?? '').toString();
                    String nomeSessao = (item['nomeSessao'] ?? '').toString();

                    if (tipo == 'Cardio') {
                      if (nomeSessao.toLowerCase().contains('bicicleta')) {
                        icone = Icons.directions_bike;
                        cor = Colors.green;
                      } else {
                        icone = Icons.directions_run;
                        cor = Colors.orange;
                      }
                    }

                    String detalhe = (item['data'] ?? '').toString();
                    String tempoStr = item['tempoTotalMinutos'] != null ? '${item['tempoTotalMinutos']}m' : '';

                    return Card(
                      child: ListTile(
                        leading: Icon(icone, color: cor),
                        title: Text(nomeSessao),
                        subtitle: Text(detalhe),
                        trailing: Text(tempoStr),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}