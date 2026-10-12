class Exercicio {
  String nome;
  int series;

  Exercicio({required this.nome, required this.series});
}

class Treino {
  String sessao;
  List<Exercicio> exercicios;

  Treino({required this.sessao, required this.exercicios});
}