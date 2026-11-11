const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const _mesesExtenso = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const _diasSemana = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

String formatarDuracao(int minutos) {
  final horas = minutos ~/ 60;
  final mins = minutos % 60;
  if (horas == 0) return '${mins}min';
  if (mins == 0) return '${horas}h';
  return '${horas}h ${mins}min';
}

/// Durações curtas mostram segundos ("45s"); as demais arredondam para minutos.
String formatarDuracaoSegundos(int segundos) {
  if (segundos > 0 && segundos < 60) return '${segundos}s';
  return formatarDuracao((segundos / 60).round());
}

/// Cronômetro "1:05:09" ou "05:09".
String formatarCronometro(Duration duracao) {
  final total = duracao.isNegative ? 0 : duracao.inSeconds;
  final horas = total ~/ 3600;
  final minutos = (total % 3600) ~/ 60;
  final segundos = total % 60;
  final ms = '${_doisDigitos(minutos)}:${_doisDigitos(segundos)}';
  return horas > 0 ? '$horas:$ms' : ms;
}

/// "Hoje", "Ontem", "Há 3 dias" ou "12 out" para datas mais antigas.
String formatarDataRelativa(DateTime data, {DateTime? agora}) {
  final hoje = inicioDoDia(agora ?? DateTime.now());
  final dias = hoje.difference(inicioDoDia(data)).inDays;

  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Ontem';
  if (dias > 1 && dias < 7) return 'Há $dias dias';

  final mesmoAno = data.year == hoje.year;
  return '${data.day} ${_meses[data.month - 1]}${mesmoAno ? '' : ' ${data.year}'}';
}

/// "Segunda, 3 de novembro"
String formatarDiaExtenso(DateTime data) {
  final dia = _diasSemana[data.weekday - 1];
  return '${dia[0].toUpperCase()}${dia.substring(1)}, ${data.day} de ${_mesesExtenso[data.month - 1]}';
}

/// "3 nov – 9 nov"
String formatarIntervalo(DateTime inicio, DateTime fim) =>
    '${inicio.day} ${_meses[inicio.month - 1]} – ${fim.day} ${_meses[fim.month - 1]}';

String formatarHora(DateTime data) => '${_doisDigitos(data.hour)}:${_doisDigitos(data.minute)}';

String nomeDoMesCurto(int mes) => _meses[mes - 1];

String formatarCarga(double kg) {
  final texto = kg == kg.truncateToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  return '$texto kg';
}

/// Inteiro com separador de milhar: "12.480".
String formatarMilhar(int valor) =>
    valor.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Volume total levantado: "850 kg", "12.480 kg".
String formatarVolume(double kg) => '${formatarMilhar(kg.round())} kg';

DateTime inicioDoDia(DateTime data) => DateTime(data.year, data.month, data.day);

String _decimal(double valor, int casas) => valor.toStringAsFixed(casas).replaceAll('.', ',');

/// "5,23 km" (ou "850 m" abaixo de 1 km).
String formatarDistancia(double metros) =>
    metros < 1000 ? '${metros.round()} m' : '${_decimal(metros / 1000, 2)} km';

/// Ritmo em min/km: "5:42". Sem dado, "--:--".
String formatarRitmo(double? segundosPorKm) {
  if (segundosPorKm == null || !segundosPorKm.isFinite || segundosPorKm > 3600) return '--:--';
  final total = segundosPorKm.round();
  return '${total ~/ 60}:${_doisDigitos(total % 60)}';
}

/// "23,4 km/h"
String formatarVelocidade(double kmh) => '${_decimal(kmh, 1)} km/h';
