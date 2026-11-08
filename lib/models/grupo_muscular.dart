enum GrupoMuscular {
  peito('chest', 'Peito'),
  costas('back', 'Costas'),
  ombros('shoulders', 'Ombros'),
  biceps('biceps', 'Bíceps'),
  triceps('triceps', 'Tríceps'),
  antebraco('forearms', 'Antebraço'),
  abdomen('abs', 'Abdômen'),
  quadriceps('quadriceps', 'Quadríceps'),
  posterior('hamstrings', 'Posterior de coxa'),
  gluteos('glutes', 'Glúteos'),
  panturrilha('calves', 'Panturrilha'),
  corpoInteiro('full_body', 'Corpo inteiro'),
  cardio('cardio', 'Cardio'),
  outro('other', 'Outro');

  final String valorApi;
  final String rotulo;

  const GrupoMuscular(this.valorApi, this.rotulo);

  static GrupoMuscular fromApi(String? valor) {
    return GrupoMuscular.values.firstWhere((g) => g.valorApi == valor, orElse: () => GrupoMuscular.outro);
  }

  static GrupoMuscular? fromApiOuNulo(String? valor) => valor == null ? null : fromApi(valor);
}
