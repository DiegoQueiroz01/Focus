class Exercicio {
  String nome;
  int series;
  int cargaKg;
  int repeticoes;

  Exercicio({
    required this.nome,
    required this.series,
    this.cargaKg = 0,
    this.repeticoes = 0,
  });

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      nome: (json['nome'] ?? '').toString(),
      series: (json['series'] as num? ?? 0).toInt(),
      cargaKg: (json['cargaKg'] as num? ?? 0).toInt(),
      repeticoes: (json['repeticoes'] as num? ?? 0).toInt(),
    );
  }
}

class Treino {
  String id;
  String nomeSessao;
  String tipo;
  String data;
  int tempoTotalMinutos;
  int seriesTotais;
  List<Exercicio> exercicios;

  Treino({
    this.id = '',
    required this.nomeSessao,
    this.tipo = 'Musculação',
    this.data = 'Hoje',
    this.tempoTotalMinutos = 0,
    this.seriesTotais = 0,
    required this.exercicios,
  });

  factory Treino.fromJson(Map<String, dynamic> json) {
    var list = json['exercicios'] as List? ?? [];
    List<Exercicio> exerciciosList = list.map((i) => Exercicio.fromJson(i)).toList();

    String nome = (json['nomeSessao'] ?? json['sessao'] ?? json['nome'] ?? 'Treino Sem Nome').toString();

    return Treino(
      id: (json['id'] ?? '').toString(),
      nomeSessao: nome.isEmpty ? 'Treino Sem Nome' : nome,
      tipo: (json['tipo'] ?? 'Musculação').toString(),
      data: (json['data'] ?? '').toString(),
      tempoTotalMinutos: (json['tempoTotalMinutos'] as num? ?? 0).toInt(),
      seriesTotais: (json['seriesTotais'] as num? ?? 0).toInt(),
      exercicios: exerciciosList,
    );
  }
}