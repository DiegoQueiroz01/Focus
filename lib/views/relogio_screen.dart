import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focus/models/saude.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/service/relogio_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/metrica_gps.dart';

/// Seção "Relógio": passos, sono, frequência cardíaca e oxigênio vindos do relógio
/// pelo Health Connect. Ao abrir, sincroniza os últimos dias e mostra o que está salvo na API.
class RelogioScreen extends StatefulWidget {
  const RelogioScreen({super.key});

  @override
  State<RelogioScreen> createState() => _RelogioScreenState();
}

class _RelogioScreenState extends State<RelogioScreen> {
  /// Quantos dias a tela mostra (e sincroniza na primeira vez).
  static const _diasHistorico = 30;

  /// Nas próximas vezes, reenvia só os últimos dias (o relógio pode sincronizar atrasado).
  static const _diasResincronizar = 3;

  final _servico = RelogioService.instance;
  final _hoje = inicioDoDia(DateTime.now());

  EstadoRelogio? _estado;
  Map<DateTime, ResumoSaudeDia> _dias = {};
  late DateTime _diaSelecionado = _hoje;
  bool _carregando = true;
  bool _sincronizando = false;
  String? _erro;
  String? _erroSync;
  DateTime? _ultimaSync;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    EstadoRelogio estado;
    try {
      estado = await _servico.verificar();
    } catch (e) {
      debugPrint('Relógio: $e');
      estado = EstadoRelogio.semHealthConnect;
    }
    if (!mounted) return;
    setState(() => _estado = estado);
    await _carregar();
    if (estado == EstadoRelogio.pronto) await _sincronizar();
  }

  Future<void> _carregar() async {
    try {
      final dias = await ApiService.instance.getResumosSaude(
        inicio: _hoje.subtract(const Duration(days: _diasHistorico - 1)),
        fim: _hoje,
      );
      if (!mounted) return;
      setState(() {
        _dias = {for (final d in dias) d.data: d};
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _sincronizar() async {
    if (_sincronizando) return;
    setState(() {
      _sincronizando = true;
      _erroSync = null;
    });
    try {
      final dias = _dias.isEmpty ? _diasHistorico : _diasResincronizar;
      await _servico.sincronizar(desde: _hoje.subtract(Duration(days: dias - 1)));
      _ultimaSync = DateTime.now();
      await _carregar();
    } on ApiException catch (e) {
      _erroSync = e.mensagem;
    } catch (e) {
      debugPrint('Relógio: falha ao sincronizar: $e');
      _erroSync = 'Não foi possível ler o Health Connect.';
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _conectar() async {
    final estado = await _servico.conectar();
    if (!mounted) return;
    setState(() => _estado = estado);
    if (estado == EstadoRelogio.pronto) {
      await _sincronizar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado foi liberado. Toque em "Conectar" para tentar de novo.')),
      );
    }
  }

  Future<void> _instalar() async {
    await _servico.instalarHealthConnect();
  }

  Future<void> _atualizar() async {
    if (_estado == EstadoRelogio.pronto) {
      await _sincronizar();
    } else {
      await _carregar();
    }
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
            Text('Relógio', style: tema.textTheme.headlineSmall),
            Text(
              'Passos, sono e coração',
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (_estado == EstadoRelogio.pronto)
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: _sincronizando ? null : _sincronizar,
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_estado == null || _carregando) return const Center(child: CircularProgressIndicator());

    final semDados = _dias.isEmpty;
    switch (_estado!) {
      case EstadoRelogio.semHealthConnect when semDados:
        return EstadoVazio(
          icone: Icons.health_and_safety_outlined,
          titulo: 'Health Connect não encontrado',
          mensagem: 'O Focus lê os dados do relógio pelo Health Connect, do Google. Instale-o para continuar.',
          rotuloAcao: 'Instalar Health Connect',
          onAcao: _instalar,
        );
      case EstadoRelogio.atualizarHealthConnect when semDados:
        return EstadoVazio(
          icone: Icons.system_update_rounded,
          titulo: 'Atualize o Health Connect',
          mensagem: 'A versão instalada é antiga demais para o Focus.',
          rotuloAcao: 'Atualizar',
          onAcao: _instalar,
        );
      case EstadoRelogio.semPermissao when semDados:
        return _Conectar(onConectar: _conectar);
      case EstadoRelogio.naoSuportado when semDados:
        return EstadoVazio(
          icone: Icons.watch_outlined,
          titulo: 'Nenhum dado do relógio ainda',
          mensagem: _erro ??
              'Abra o Focus no celular Android para sincronizar. Os dados aparecerão aqui também.',
          rotuloAcao: _erro != null ? 'Tentar novamente' : null,
          onAcao: _erro != null ? _carregar : null,
        );
      default:
        break;
    }

    final resumo = _dias[_diaSelecionado];
    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Aviso(
            estado: _estado!,
            sincronizando: _sincronizando,
            ultimaSync: _ultimaSync,
            erro: _erroSync ?? _erro,
            onConectar: _conectar,
          ),
          _SeletorDia(
            dia: _diaSelecionado,
            hoje: _hoje,
            minimo: _hoje.subtract(const Duration(days: _diasHistorico - 1)),
            onMudar: (d) => setState(() => _diaSelecionado = d),
          ),
          const SizedBox(height: 8),
          if (resumo == null || resumo.vazio)
            _SemDadosNoDia(sincronizando: _sincronizando)
          else ...[
            _CardAtividade(resumo: resumo),
            if (resumo.temSono) _CardSono(resumo: resumo),
            if (resumo.temFrequencia) _CardCoracao(resumo: resumo),
            if (resumo.oxigenioMedio != null) _CardOxigenio(resumo: resumo),
          ],
          _CardSemana(
            dias: _dias,
            fim: _diaSelecionado,
            selecionado: _diaSelecionado,
            onSelecionar: (d) => setState(() => _diaSelecionado = d),
          ),
        ],
      ),
    );
  }
}

/// Primeira vez: explica o caminho relógio → Fitbeing → Health Connect → Focus.
class _Conectar extends StatelessWidget {
  final VoidCallback onConectar;

  const _Conectar({required this.onConectar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    Widget passo(int numero, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: esquema.primary.withValues(alpha: 0.14),
                child: Text('$numero', style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: tema.textTheme.bodyMedium)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.watch_rounded, size: 56, color: esquema.primary),
        const SizedBox(height: 16),
        Text('Conecte seu relógio', textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'O Focus lê os passos, o sono, a frequência cardíaca e o oxigênio que o app do relógio grava no Health Connect.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        passo(1, 'No app do relógio (Fitbeing), ative a integração com o Health Connect.'),
        passo(2, 'Toque em "Conectar" abaixo e libere os dados que o Focus pode ler.'),
        passo(3, 'Pronto. Sempre que você abrir esta tela, os dados dos últimos dias são atualizados.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onConectar,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Conectar'),
        ),
      ],
    );
  }
}

/// Linha de status no topo: sincronizando, última sincronização, erro ou pedido de permissão.
class _Aviso extends StatelessWidget {
  final EstadoRelogio estado;
  final bool sincronizando;
  final DateTime? ultimaSync;
  final String? erro;
  final VoidCallback onConectar;

  const _Aviso({
    required this.estado,
    required this.sincronizando,
    required this.ultimaSync,
    required this.erro,
    required this.onConectar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estilo = tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant);

    if (sincronizando) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lendo dados do Health Connect…', style: estilo),
            const SizedBox(height: 6),
            const LinearProgressIndicator(),
          ],
        ),
      );
    }

    final (icone, texto, acao) = switch (estado) {
      _ when erro != null => (Icons.error_outline_rounded, erro!, null),
      EstadoRelogio.semPermissao => (Icons.link_off_rounded, 'Acesso ao Health Connect desligado.', onConectar),
      EstadoRelogio.naoSuportado => (Icons.phone_android_rounded, 'A sincronização é feita pelo app no Android.', null),
      EstadoRelogio.semHealthConnect ||
      EstadoRelogio.atualizarHealthConnect =>
        (Icons.health_and_safety_outlined, 'Health Connect indisponível neste aparelho.', null),
      EstadoRelogio.pronto => (
          Icons.check_circle_outline_rounded,
          ultimaSync == null ? 'Conectado ao Health Connect' : 'Atualizado às ${formatarHora(ultimaSync!)}',
          null,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icone, size: 16, color: erro != null ? esquema.error : esquema.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: estilo)),
          if (acao != null) TextButton(onPressed: acao, child: const Text('Conectar')),
        ],
      ),
    );
  }
}

class _SeletorDia extends StatelessWidget {
  final DateTime dia;
  final DateTime hoje;
  final DateTime minimo;
  final ValueChanged<DateTime> onMudar;

  const _SeletorDia({required this.dia, required this.hoje, required this.minimo, required this.onMudar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final relativo = formatarDataRelativa(dia, agora: hoje);
    final titulo = relativo == 'Hoje' || relativo == 'Ontem' ? relativo : formatarDiaExtenso(dia);

    return Row(
      children: [
        IconButton(
          tooltip: 'Dia anterior',
          onPressed: dia.isAfter(minimo) ? () => onMudar(DateTime(dia.year, dia.month, dia.day - 1)) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(child: Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.titleMedium)),
        IconButton(
          tooltip: 'Próximo dia',
          onPressed: dia.isBefore(hoje) ? () => onMudar(DateTime(dia.year, dia.month, dia.day + 1)) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SemDadosNoDia extends StatelessWidget {
  final bool sincronizando;

  const _SemDadosNoDia({required this.sincronizando});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.watch_off_outlined, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sincronizando
                    ? 'Buscando os dados deste dia…'
                    : 'Sem dados do relógio neste dia. Sincronize o relógio no Fitbeing e puxe a tela para atualizar.',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card com título em caixa alta e ícone, no mesmo estilo dos resumos do GPS.
class _CardSecao extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final List<Widget> children;

  const _CardSecao({required this.titulo, required this.icone, required this.children});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16, color: esquema.primary),
                const SizedBox(width: 6),
                Text(
                  titulo.toUpperCase(),
                  style: tema.textTheme.labelMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CardAtividade extends StatelessWidget {
  final ResumoSaudeDia resumo;

  const _CardAtividade({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final passos = resumo.passos ?? 0;
    final progresso = (passos / metaPassosPadrao).clamp(0.0, 1.0);

    return _CardSecao(
      titulo: 'Atividade',
      icone: Icons.directions_walk_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              resumo.passos == null ? '--' : formatarMilhar(passos),
              style: tema.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('passos', style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Meta ${formatarMilhar(metaPassosPadrao)}',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: progresso, minHeight: 8),
        ),
        const SizedBox(height: 16),
        GradeMetricas(
          colunas: 2,
          itens: [
            MetricaGps(
              rotulo: 'Distância',
              icone: Icons.straighten_rounded,
              valor: resumo.distanciaMetros == null ? '--' : formatarDistancia(resumo.distanciaMetros!),
            ),
            MetricaGps(
              rotulo: 'Calorias',
              icone: Icons.local_fire_department_outlined,
              valor: resumo.calorias == null ? '--' : '${formatarMilhar(resumo.calorias!)} kcal',
            ),
          ],
        ),
      ],
    );
  }
}

class _CardSono extends StatelessWidget {
  final ResumoSaudeDia resumo;

  const _CardSono({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estagios = [
      ('Profundo', resumo.sonoProfundoMinutos ?? 0, esquema.primary),
      ('Leve', resumo.sonoLeveMinutos ?? 0, esquema.primary.withValues(alpha: 0.45)),
      ('REM', resumo.sonoRemMinutos ?? 0, esquema.tertiary),
      ('Acordado', resumo.sonoAcordadoMinutos ?? 0, esquema.error.withValues(alpha: 0.6)),
    ].where((e) => e.$2 > 0).toList();

    return _CardSecao(
      titulo: 'Sono',
      icone: Icons.bedtime_outlined,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatarDuracao(resumo.sonoMinutos!),
              style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (resumo.dormiuEm != null && resumo.acordouEm != null)
              Text(
                '${formatarHora(resumo.dormiuEm!)} – ${formatarHora(resumo.acordouEm!)}',
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
          ],
        ),
        if (estagios.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final (_, minutos, cor) in estagios)
                    Expanded(flex: minutos, child: ColoredBox(color: cor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final (nome, minutos, cor) in estagios)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$nome ${formatarDuracao(minutos)}', style: tema.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CardCoracao extends StatelessWidget {
  final ResumoSaudeDia resumo;

  const _CardCoracao({required this.resumo});

  @override
  Widget build(BuildContext context) {
    String bpm(int? v) => v == null ? '--' : '$v';
    return _CardSecao(
      titulo: 'Frequência cardíaca',
      icone: Icons.favorite_outline_rounded,
      children: [
        GradeMetricas(
          colunas: 4,
          itens: [
            MetricaGps(rotulo: 'Repouso', valor: bpm(resumo.frequenciaRepouso)),
            MetricaGps(rotulo: 'Média', valor: bpm(resumo.frequenciaMedia)),
            MetricaGps(rotulo: 'Mínima', valor: bpm(resumo.frequenciaMinima)),
            MetricaGps(rotulo: 'Máxima', valor: bpm(resumo.frequenciaMaxima)),
          ],
        ),
        if (resumo.serieFrequencia.length > 1) ...[
          const SizedBox(height: 16),
          _GraficoFrequencia(serie: resumo.serieFrequencia),
        ],
        const SizedBox(height: 4),
        Text(
          'Valores em batimentos por minuto (bpm).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CardOxigenio extends StatelessWidget {
  final ResumoSaudeDia resumo;

  const _CardOxigenio({required this.resumo});

  @override
  Widget build(BuildContext context) {
    String pct(double? v) => v == null ? '--' : '${v.round()}%';
    return _CardSecao(
      titulo: 'Oxigênio no sangue',
      icone: Icons.water_drop_outlined,
      children: [
        GradeMetricas(
          colunas: 2,
          itens: [
            MetricaGps(rotulo: 'Média', valor: pct(resumo.oxigenioMedio)),
            MetricaGps(rotulo: 'Mínima', valor: pct(resumo.oxigenioMinimo)),
          ],
        ),
      ],
    );
  }
}

/// Passos dos 7 dias que terminam em [fim]. Tocar numa barra abre aquele dia.
class _CardSemana extends StatelessWidget {
  static const _iniciais = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  final Map<DateTime, ResumoSaudeDia> dias;
  final DateTime fim;
  final DateTime selecionado;
  final ValueChanged<DateTime> onSelecionar;

  const _CardSemana({required this.dias, required this.fim, required this.selecionado, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final semana = [for (var i = 6; i >= 0; i--) DateTime(fim.year, fim.month, fim.day - i)];
    final passos = [for (final d in semana) dias[d]?.passos ?? 0];
    final maximo = math.max(metaPassosPadrao, passos.reduce(math.max));
    final comDados = passos.where((p) => p > 0).toList();
    final media = comDados.isEmpty ? 0 : comDados.reduce((a, b) => a + b) ~/ comDados.length;

    return _CardSecao(
      titulo: 'Passos em 7 dias',
      icone: Icons.bar_chart_rounded,
      children: [
        Text(
          'Média ${formatarMilhar(media)} por dia',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, dia) in semana.indexed)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelecionar(dia),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: math.max(passos[i] / maximo, 0.02),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: dia == selecionado
                                      ? esquema.primary
                                      : esquema.primary.withValues(alpha: passos[i] >= metaPassosPadrao ? 0.6 : 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _iniciais[dia.weekday - 1],
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: dia == selecionado ? esquema.primary : esquema.onSurfaceVariant,
                              fontWeight: dia == selecionado ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Linha da frequência cardíaca ao longo do dia (0h a 24h).
class _GraficoFrequencia extends StatelessWidget {
  final List<(int, int)> serie;

  const _GraficoFrequencia({required this.serie});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorFrequencia(
          serie: serie,
          cor: esquema.error,
          grade: esquema.outlineVariant,
          texto: esquema.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PintorFrequencia extends CustomPainter {
  final List<(int, int)> serie;
  final Color cor;
  final Color grade;
  final Color texto;

  _PintorFrequencia({required this.serie, required this.cor, required this.grade, required this.texto});

  @override
  void paint(Canvas canvas, Size size) {
    const rodape = 16.0;
    const margemDireita = 28.0;
    final largura = size.width - margemDireita;
    final altura = size.height - rodape;
    final valores = [for (final (_, b) in serie) b];
    final minimo = valores.reduce(math.min) - 5;
    final maximo = valores.reduce(math.max) + 5;
    double x(int minuto) => minuto / 1440 * largura;
    double y(int bpm) => (maximo - bpm) / (maximo - minimo) * altura;

    void escrever(String s, Offset pos) {
      final pintor = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: texto, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      pintor.paint(canvas, pos - Offset(0, pintor.height / 2));
    }

    final linhaGrade = Paint()
      ..color = grade
      ..strokeWidth = 1;
    for (final bpm in [maximo - 5, minimo + 5]) {
      canvas.drawLine(Offset(0, y(bpm)), Offset(largura, y(bpm)), linhaGrade);
      escrever('$bpm', Offset(largura + 6, y(bpm)));
    }
    for (final hora in [0, 6, 12, 18]) {
      escrever('${hora}h', Offset(x(hora * 60), size.height - rodape / 2));
    }

    // Quebra a linha onde faltam mais de 30 min de dados (relógio fora do pulso).
    final caminho = Path();
    int? anterior;
    for (final (minuto, bpm) in serie) {
      final ponto = Offset(x(minuto), y(bpm));
      if (anterior == null || minuto - anterior > 30) {
        caminho.moveTo(ponto.dx, ponto.dy);
      } else {
        caminho.lineTo(ponto.dx, ponto.dy);
      }
      anterior = minuto;
    }
    canvas.drawPath(
      caminho,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorFrequencia antigo) => antigo.serie != serie || antigo.cor != cor;
}
