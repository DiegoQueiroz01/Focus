class DashboardResumo {
  final int totalTreinos;
  final int seriesTotais;
  final int tempoTotalMinutos;

  const DashboardResumo({
    required this.totalTreinos,
    required this.seriesTotais,
    required this.tempoTotalMinutos,
  });

  factory DashboardResumo.fromJson(Map<String, dynamic> json) {
    return DashboardResumo(
      totalTreinos: (json['total_workouts'] as num).toInt(),
      seriesTotais: (json['total_sets'] as num).toInt(),
      tempoTotalMinutos: (json['total_minutes'] as num).toInt(),
    );
  }
}
