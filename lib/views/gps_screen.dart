import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/gps_resumo_screen.dart';
import 'package:focus/views/gps_sessao_screen.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/mapa_trajeto.dart';
import 'package:focus/widgets/metrica_gps.dart';

/// Seção "GPS": histórico de atividades ao ar livre e início de uma nova gravação.
class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  late Future<List<AtividadeGps>> _atividades = ApiService.instance.getAtividadesGps(limite: 50);

  Future<void> _recarregar() async {
    final novas = ApiService.instance.getAtividadesGps(limite: 50);
    setState(() {
      _atividades = novas;
    });
    await novas.catchError((_) => <AtividadeGps>[]);
  }

  Future<void> _novaAtividade() async {
    final escolha = await showModalBottomSheet<(TipoAtividadeGps, bool)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _EscolherTipo(),
    );
    if (escolha == null || !mounted) return;
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GpsSessaoScreen(tipo: escolha.$1, simular: escolha.$2)),
    );
    if (salvou == true && mounted) await _recarregar();
  }

  Future<void> _abrir(AtividadeGps atividade) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GpsResumoScreen.salva(id: atividade.id!, previa: atividade)),
    );
    if (mounted) await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: const BotaoMenu(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPS', style: tema.textTheme.headlineSmall),
            Text(
              'Corridas, pedais e caminhadas',
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novaAtividade,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Nova atividade'),
      ),
      body: FutureBuilder<List<AtividadeGps>>(
        future: _atividades,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EstadoVazio(
              icone: Icons.cloud_off_rounded,
              titulo: 'Não foi possível carregar',
              mensagem: snapshot.error.toString(),
              rotuloAcao: 'Tentar novamente',
              onAcao: _recarregar,
            );
          }
          final atividades = snapshot.data;
          if (atividades == null) return const Center(child: CircularProgressIndicator());
          if (atividades.isEmpty) {
            return EstadoVazio(
              icone: Icons.route_rounded,
              titulo: 'Nenhuma atividade gravada',
              mensagem: 'Toque em "Nova atividade" para gravar sua primeira corrida, pedal ou caminhada.',
              rotuloAcao: 'Nova atividade',
              onAcao: _novaAtividade,
            );
          }
          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _ResumoDoMes(atividades: atividades),
                const SizedBox(height: 16),
                for (final atividade in atividades)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CardAtividade(atividade: atividade, onTap: () => _abrir(atividade)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResumoDoMes extends StatelessWidget {
  final List<AtividadeGps> atividades;

  const _ResumoDoMes({required this.atividades});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final doMes = atividades.where((a) => a.iniciadaEm.year == agora.year && a.iniciadaEm.month == agora.month);
    final distancia = doMes.fold<double>(0, (s, a) => s + a.distanciaMetros);
    final tempo = doMes.fold<int>(0, (s, a) => s + a.tempoMovimentoSegundos);
    final calorias = doMes.fold<int>(0, (s, a) => s + a.calorias);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EM ${nomeDoMesCurto(agora.month).toUpperCase()}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            GradeMetricas(
              colunas: 4,
              itens: [
                MetricaGps(rotulo: 'Atividades', valor: '${doMes.length}'),
                MetricaGps(rotulo: 'Distância', valor: formatarDistancia(distancia)),
                MetricaGps(rotulo: 'Tempo', valor: formatarDuracaoSegundos(tempo)),
                MetricaGps(rotulo: 'Calorias', valor: '$calorias'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAtividade extends StatelessWidget {
  final AtividadeGps atividade;
  final VoidCallback onTap;

  const _CardAtividade({required this.atividade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ritmo = ritmoOuVelocidade(atividade.tipo, atividade.ritmoMedio);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 2.4, child: MapaTrajeto(trajeto: atividade.trajeto)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: esquema.primary.withValues(alpha: 0.14),
                        child: Icon(atividade.tipo.icone, size: 18, color: esquema.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(atividade.tipo.rotulo, style: tema.textTheme.titleMedium),
                            Text(
                              '${formatarDataRelativa(atividade.iniciadaEm)} · ${formatarHora(atividade.iniciadaEm)}',
                              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (atividade.comentario != null)
                        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: esquema.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradeMetricas(
                    colunas: 4,
                    itens: [
                      MetricaGps(rotulo: 'Distância', valor: formatarDistancia(atividade.distanciaMetros)),
                      MetricaGps(
                        rotulo: 'Tempo',
                        valor: formatarCronometro(Duration(seconds: atividade.tempoMovimentoSegundos)),
                      ),
                      MetricaGps(rotulo: ritmo.rotulo, valor: ritmo.valor),
                      MetricaGps(rotulo: 'Calorias', valor: '${atividade.calorias} kcal'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista das atividades ao ar livre. No Windows/Web (sem GPS) ou em modo debug,
/// oferece a opção de simular um percurso para testar as telas.
class _EscolherTipo extends StatefulWidget {
  const _EscolherTipo();

  @override
  State<_EscolherTipo> createState() => _EscolherTipoState();
}

class _EscolherTipoState extends State<_EscolherTipo> {
  static final bool _celular =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  bool _simular = !_celular;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nova atividade', textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Escolha o que você vai fazer',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final tipo in TipoAtividadeGps.values)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(tipo.icone, color: tema.colorScheme.primary),
                title: Text(tipo.rotulo),
                subtitle: Text(tipo.usaVelocidade ? 'Mostra velocidade (km/h)' : 'Mostra ritmo (min/km)'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, (tipo, _simular)),
              ),
            if (!_celular || kDebugMode) ...[
              const Divider(height: 24),
              SwitchListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                secondary: const Icon(Icons.science_outlined),
                title: const Text('Simular percurso'),
                subtitle: Text(_celular
                    ? 'Usa um trajeto de teste em vez do GPS.'
                    : 'Este aparelho não tem GPS; usa um trajeto de teste.'),
                value: _simular,
                onChanged: (v) => setState(() => _simular = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
