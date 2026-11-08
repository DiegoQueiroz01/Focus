import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/service/rastreador_gps.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/gps_resumo_screen.dart';
import 'package:focus/widgets/dialogo_padrao.dart';
import 'package:focus/widgets/mapa_trajeto.dart';
import 'package:focus/widgets/metrica_gps.dart';
import 'package:latlong2/latlong.dart';

/// Gravação ao vivo: mapa com a posição e o trajeto, métricas e controles.
/// Retorna true se a atividade foi salva.
class GpsSessaoScreen extends StatefulWidget {
  final TipoAtividadeGps tipo;
  final bool simular;

  /// Permite trocar a fonte de localização nos testes.
  final FonteLocalizacao? fonte;

  const GpsSessaoScreen({super.key, required this.tipo, this.simular = false, this.fonte});

  @override
  State<GpsSessaoScreen> createState() => _GpsSessaoScreenState();
}

class _GpsSessaoScreenState extends State<GpsSessaoScreen> {
  late final RastreadorGps _rastreador = RastreadorGps(
    tipo: widget.tipo,
    fonte: widget.fonte ?? (widget.simular ? FonteSimulada.para(widget.tipo) : const FonteGeolocator()),
  );
  final _mapa = MapController();
  bool _mapaPronto = false;
  bool _seguir = true;
  LatLng? _ultimaPosicaoCentralizada;

  @override
  void initState() {
    super.initState();
    _rastreador.addListener(_acompanharPosicao);
    _rastreador.conectar();
  }

  @override
  void dispose() {
    _rastreador.removeListener(_acompanharPosicao);
    _rastreador.dispose();
    super.dispose();
  }

  void _acompanharPosicao() {
    final posicao = _rastreador.posicaoAtual?.latLng;
    if (!_seguir || !_mapaPronto || posicao == null || posicao == _ultimaPosicaoCentralizada) return;
    final primeiraVez = _ultimaPosicaoCentralizada == null;
    _ultimaPosicaoCentralizada = posicao;
    _mapa.move(posicao, primeiraVez ? 17 : _mapa.camera.zoom);
  }

  void _recentralizar() {
    setState(() => _seguir = true);
    _ultimaPosicaoCentralizada = null;
    _acompanharPosicao();
  }

  Future<void> _encerrar() async {
    final ok = await confirmar(
      context,
      titulo: 'Encerrar atividade?',
      mensagem: 'A gravação será finalizada e você verá o resumo.',
      rotuloConfirmar: 'Encerrar',
      rotuloCancelar: 'Continuar gravando',
      icone: Icons.flag_rounded,
    );
    if (!ok || !mounted) return;
    final atividade = _rastreador.finalizar();
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GpsResumoScreen.nova(atividade: atividade)),
    );
    if (mounted) Navigator.of(context).pop(salvou ?? false);
  }

  Future<void> _sairSemSalvar() async {
    final ok = await confirmar(
      context,
      titulo: 'Descartar atividade?',
      mensagem: 'O que foi gravado até agora será perdido.',
      rotuloConfirmar: 'Descartar',
      icone: Icons.delete_outline_rounded,
      destrutivo: true,
    );
    if (ok && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rastreador,
      builder: (context, _) {
        final aguardando = _rastreador.estado == EstadoGravacao.aguardando;
        return PopScope(
          canPop: aguardando,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _sairSemSalvar();
          },
          child: Scaffold(
            body: Column(
              children: [
                Expanded(child: _construirMapa(context)),
                _PainelMetricas(
                  rastreador: _rastreador,
                  onIniciar: _rastreador.iniciar,
                  onPausar: _rastreador.pausar,
                  onRetomar: _rastreador.retomar,
                  onEncerrar: _encerrar,
                  onTentarDeNovo: () {
                    _rastreador.erro = null;
                    _rastreador.conectar();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirMapa(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final posicao = _rastreador.posicaoAtual;
    final trajeto = _rastreador.trajeto;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: posicao?.latLng ?? const LatLng(-14.235, -51.925),
            initialZoom: posicao == null ? 4 : 17,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _mapaPronto = true;
              _acompanharPosicao();
            },
            onPositionChanged: (_, comGesto) {
              if (comGesto && _seguir) setState(() => _seguir = false);
            },
          ),
          children: [
            const CamadaMapa(),
            if (trajeto.length > 1) camadaTrajeto(context, trajeto, espessura: 5),
            MarkerLayer(
              markers: [
                if (trajeto.isNotEmpty) marcadorPonto(trajeto.first, inicio: true),
                if (posicao != null)
                  Marker(
                    point: posicao.latLng,
                    width: 26,
                    height: 26,
                    child: _MarcadorPosicao(cor: esquema.primary),
                  ),
              ],
            ),
            const CreditoMapa(),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BotaoRedondo(
                  icone: Icons.arrow_back_rounded,
                  dica: 'Voltar',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                _ChipStatus(rastreador: _rastreador),
                const Spacer(),
                _BotaoRedondo(
                  icone: _seguir ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  dica: 'Centralizar',
                  onTap: _recentralizar,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PainelMetricas extends StatelessWidget {
  final RastreadorGps rastreador;
  final VoidCallback onIniciar;
  final VoidCallback onPausar;
  final VoidCallback onRetomar;
  final VoidCallback onEncerrar;
  final VoidCallback onTentarDeNovo;

  const _PainelMetricas({
    required this.rastreador,
    required this.onIniciar,
    required this.onPausar,
    required this.onRetomar,
    required this.onEncerrar,
    required this.onTentarDeNovo,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final r = rastreador;
    final tipo = r.tipo;
    final atual = ritmoOuVelocidade(tipo, r.ritmoAtual, prefixo: '');
    final media = ritmoOuVelocidade(tipo, r.ritmoMedio, prefixo: '');
    final kmAtual = r.parciais.length + 1;
    final ritmoKm = r.distanciaNoKmAtual < 50 ? null : r.segundosNoKmAtual / (r.distanciaNoKmAtual / 1000);

    return Material(
      color: esquema.surfaceContainerLowest,
      elevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricaGps(
                      rotulo: 'Tempo',
                      valor: formatarCronometro(r.tempoAtivo),
                      icone: Icons.timer_outlined,
                      grande: true,
                    ),
                  ),
                  Expanded(
                    child: MetricaGps(
                      rotulo: 'Distância (km)',
                      valor: (r.distancia / 1000).toStringAsFixed(2).replaceAll('.', ','),
                      icone: Icons.route_rounded,
                      grande: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GradeMetricas(
                colunas: 3,
                itens: [
                  MetricaGps(rotulo: '${atual.rotulo} atual', valor: atual.valor, icone: Icons.speed_rounded),
                  MetricaGps(rotulo: '${media.rotulo} média', valor: media.valor),
                  MetricaGps(
                    rotulo: 'Km $kmAtual',
                    valor: ritmoOuVelocidade(tipo, ritmoKm).valor,
                    icone: Icons.flag_outlined,
                  ),
                  MetricaGps(
                    rotulo: 'Elevação',
                    valor: '↑${r.ganhoElevacao.round()} ↓${r.perdaElevacao.round()} m',
                    icone: Icons.terrain_outlined,
                  ),
                  MetricaGps(
                    rotulo: 'Altitude',
                    valor: r.altitudeAtual == null ? '--' : '${r.altitudeAtual!.round()} m',
                  ),
                  MetricaGps(
                    rotulo: 'Calorias',
                    valor: '${r.calorias} kcal',
                    icone: Icons.local_fire_department_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Controles(
                rastreador: r,
                onIniciar: onIniciar,
                onPausar: onPausar,
                onRetomar: onRetomar,
                onEncerrar: onEncerrar,
                onTentarDeNovo: onTentarDeNovo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  final RastreadorGps rastreador;
  final VoidCallback onIniciar;
  final VoidCallback onPausar;
  final VoidCallback onRetomar;
  final VoidCallback onEncerrar;
  final VoidCallback onTentarDeNovo;

  const _Controles({
    required this.rastreador,
    required this.onIniciar,
    required this.onPausar,
    required this.onRetomar,
    required this.onEncerrar,
    required this.onTentarDeNovo,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    const altura = Size.fromHeight(52);

    if (rastreador.erro != null && rastreador.estado == EstadoGravacao.aguardando) {
      return Column(
        children: [
          Text(rastreador.erro!, textAlign: TextAlign.center, style: TextStyle(color: esquema.error)),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: altura),
            onPressed: onTentarDeNovo,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    return switch (rastreador.estado) {
      EstadoGravacao.aguardando => FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: altura),
          onPressed: rastreador.temSinal ? onIniciar : null,
          icon: rastreador.temSinal
              ? const Icon(Icons.play_arrow_rounded)
              : const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          label: Text(rastreador.temSinal ? 'Iniciar' : 'Procurando sinal do GPS...'),
        ),
      EstadoGravacao.gravando => FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: altura),
          onPressed: onPausar,
          icon: const Icon(Icons.pause_rounded),
          label: const Text('Pausar'),
        ),
      EstadoGravacao.pausado => Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: altura),
                onPressed: onRetomar,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Retomar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: altura),
                onPressed: onEncerrar,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Encerrar'),
              ),
            ),
          ],
        ),
    };
  }
}

class _ChipStatus extends StatelessWidget {
  final RastreadorGps rastreador;

  const _ChipStatus({required this.rastreador});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final precisao = rastreador.posicaoAtual?.precisao;
    final (texto, cor) = switch (rastreador.estado) {
      EstadoGravacao.gravando => ('Gravando', esquema.primary),
      EstadoGravacao.pausado => ('Pausado', Colors.orange),
      EstadoGravacao.aguardando when !rastreador.temSinal => ('Sem sinal', esquema.error),
      EstadoGravacao.aguardando => ('GPS pronto', esquema.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: cor),
          const SizedBox(width: 6),
          Text('${rastreador.tipo.rotulo} · $texto', style: Theme.of(context).textTheme.labelLarge),
          if (precisao != null) ...[
            const SizedBox(width: 6),
            Text('±${precisao.round()} m', style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  final IconData icone;
  final String dica;
  final VoidCallback onTap;

  const _BotaoRedondo({required this.icone, required this.dica, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(icon: Icon(icone), tooltip: dica, onPressed: onTap),
    );
  }
}

/// Ponto azul-esverdeado com halo, como nos apps de mapa.
class _MarcadorPosicao extends StatelessWidget {
  final Color cor;

  const _MarcadorPosicao({required this.cor});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.25), shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
        ),
      ),
    );
  }
}
