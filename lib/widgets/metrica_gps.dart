import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/utils/formatadores.dart';

/// Rótulo pequeno em cima e valor embaixo, usado nas telas de GPS.
class MetricaGps extends StatelessWidget {
  final String rotulo;
  final String valor;
  final IconData? icone;
  final bool grande;

  const MetricaGps({super.key, required this.rotulo, required this.valor, this.icone, this.grande = false});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[Icon(icone, size: 14, color: secundario), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelSmall?.copyWith(color: secundario),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: (grande ? tema.textTheme.headlineMedium : tema.textTheme.titleMedium)?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Grade de métricas com colunas de largura igual.
class GradeMetricas extends StatelessWidget {
  final List<Widget> itens;
  final int colunas;

  const GradeMetricas({super.key, required this.itens, this.colunas = 3});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final largura = (restricoes.maxWidth - (colunas - 1) * 12) / colunas;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [for (final item in itens) SizedBox(width: largura, child: item)],
        );
      },
    );
  }
}

/// Ritmo ("5:42 /km") para corrida e caminhada; velocidade ("23,4 km/h") para pedal e patins.
({String rotulo, String valor}) ritmoOuVelocidade(TipoAtividadeGps tipo, double? segundosPorKm, {String prefixo = ''}) {
  if (tipo.usaVelocidade) {
    final kmh = segundosPorKm == null || segundosPorKm <= 0 ? 0.0 : 3600 / segundosPorKm;
    return (rotulo: '${prefixo}Velocidade', valor: formatarVelocidade(kmh));
  }
  return (rotulo: '${prefixo}Ritmo', valor: '${formatarRitmo(segundosPorKm)} /km');
}
