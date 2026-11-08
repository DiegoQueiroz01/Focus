import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa base do OpenStreetMap. No tema escuro as cores são invertidas para combinar com o app.
class CamadaMapa extends StatelessWidget {
  const CamadaMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.focus',
      maxZoom: 19,
      tileBuilder: escuro ? darkModeTileBuilder : null,
    );
  }
}

/// Crédito exigido pelos provedores do mapa.
class CreditoMapa extends StatelessWidget {
  const CreditoMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: esquema.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('© OpenStreetMap', style: TextStyle(fontSize: 8, color: esquema.onSurfaceVariant)),
      ),
    );
  }
}

/// Linha do trajeto com contorno, para ficar visível sobre qualquer fundo.
PolylineLayer camadaTrajeto(BuildContext context, List<LatLng> pontos, {double espessura = 4}) {
  final esquema = Theme.of(context).colorScheme;
  return PolylineLayer(
    polylines: [
      Polyline(
        points: pontos,
        strokeWidth: espessura,
        color: esquema.primary,
        borderStrokeWidth: espessura / 2,
        borderColor: esquema.surface.withValues(alpha: 0.8),
      ),
    ],
  );
}

/// Bolinha de início (verde) ou fim (quadriculado escuro) do trajeto.
Marker marcadorPonto(LatLng ponto, {required bool inicio, double tamanho = 14}) => Marker(
      point: ponto,
      width: tamanho,
      height: tamanho,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: inicio ? const Color(0xFF16A34A) : const Color(0xFF111312),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );

/// Trajeto já gravado, enquadrado no mapa. Usado nos cards do histórico e no resumo.
class MapaTrajeto extends StatelessWidget {
  final List<LatLng> trajeto;
  final bool interativo;

  const MapaTrajeto({super.key, required this.trajeto, this.interativo = false});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (trajeto.isEmpty) {
      return ColoredBox(
        color: esquema.surfaceContainer,
        child: Center(child: Icon(Icons.location_off_rounded, color: esquema.onSurfaceVariant)),
      );
    }

    final mapa = FlutterMap(
      // Recria o mapa se o trajeto mudar, para reenquadrar.
      key: ValueKey(Object.hash(trajeto.length, trajeto.first, trajeto.last)),
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: trajeto,
          padding: const EdgeInsets.all(24),
          maxZoom: 17,
        ),
        interactionOptions: InteractionOptions(
          flags: interativo ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
      ),
      children: [
        const CamadaMapa(),
        camadaTrajeto(context, trajeto, espessura: interativo ? 5 : 3),
        MarkerLayer(
          markers: [
            marcadorPonto(trajeto.first, inicio: true, tamanho: interativo ? 16 : 10),
            if (trajeto.length > 1) marcadorPonto(trajeto.last, inicio: false, tamanho: interativo ? 16 : 10),
          ],
        ),
        const CreditoMapa(),
      ],
    );
    // Nos cards o toque vai para o card, não para o mapa.
    return interativo ? mapa : IgnorePointer(child: mapa);
  }
}
