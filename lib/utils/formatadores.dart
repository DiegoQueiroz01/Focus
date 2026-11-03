const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String formatarDuracao(int minutos) {
  final horas = minutos ~/ 60;
  final mins = minutos % 60;
  if (horas == 0) return '${mins}min';
  if (mins == 0) return '${horas}h';
  return '${horas}h ${mins}min';
}

/// "Hoje", "Ontem", "Há 3 dias" ou "12 out" para datas mais antigas.
String formatarDataRelativa(DateTime data, {DateTime? agora}) {
  final hoje = _inicioDoDia(agora ?? DateTime.now());
  final dias = hoje.difference(_inicioDoDia(data)).inDays;

  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Ontem';
  if (dias > 1 && dias < 7) return 'Há $dias dias';

  final mesmoAno = data.year == hoje.year;
  return '${data.day} ${_meses[data.month - 1]}${mesmoAno ? '' : ' ${data.year}'}';
}

String formatarCarga(double kg) {
  final texto = kg == kg.truncateToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  return '$texto kg';
}

DateTime _inicioDoDia(DateTime data) => DateTime(data.year, data.month, data.day);
