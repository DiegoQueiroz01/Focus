enum GrupoMuscular {
  peito('chest', 'Peito'),
  costas('back', 'Costas'),
  ombros('shoulders', 'Ombros'),
  biceps('biceps', 'Bíceps'),
  triceps('triceps', 'Tríceps'),
  antebraco('forearms', 'Antebraço'),
  trapezio('traps', 'Trapézio'),
  lombar('lower_back', 'Lombar'),
  abdomen('abs', 'Abdômen'),
  quadriceps('quadriceps', 'Quadríceps'),
  posterior('hamstrings', 'Posterior de coxa'),
  gluteos('glutes', 'Glúteos'),
  adutores('adductors', 'Adutores'),
  abdutores('abductors', 'Abdutores'),
  panturrilha('calves', 'Panturrilha'),
  pescoco('neck', 'Pescoço'),
  corpoInteiro('full_body', 'Corpo inteiro'),
  cardio('cardio', 'Cardio'),
  outro('other', 'Outro');

  final String valorApi;
  final String rotulo;

  const GrupoMuscular(this.valorApi, this.rotulo);

  static GrupoMuscular fromApi(String? valor) {
    return GrupoMuscular.values.firstWhere((g) => g.valorApi == valor, orElse: () => GrupoMuscular.outro);
  }

  /// Grupos usados no filtro do catálogo de musculação.
  static const filtroMusculacao = [
    peito, costas, ombros, biceps, triceps, antebraco, trapezio, abdomen, lombar,
    quadriceps, posterior, gluteos, adutores, abdutores, panturrilha, pescoco,
  ];

  static GrupoMuscular? fromApiOuNulo(String? valor) => valor == null ? null : fromApi(valor);
}
