import 'package:flutter/material.dart';
import 'package:focus/service/tema_controller.dart';
import 'package:focus/theme/cor_destaque.dart';

/// Abre a janela para escolher a cor de destaque do app.
Future<void> mostrarSeletorCores(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SeletorCores(),
  );
}

class SeletorCores extends StatelessWidget {
  const SeletorCores({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TemaController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tema = Theme.of(context);
        final esquema = tema.colorScheme;
        final atual = controller.cor;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cores do app', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Escolha a cor dos botões, ícones e destaques.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    for (final cor in CorDestaque.prontas)
                      _BolinhaCor(
                        cor: cor.para(tema.brightness),
                        nome: cor.nome,
                        selecionada: cor == atual,
                        onTap: () => controller.definirCor(cor),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text('Personalizada', style: tema.textTheme.titleMedium),
                    const Spacer(),
                    if (atual.ehPersonalizada)
                      Icon(Icons.check_circle_rounded, color: esquema.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Arraste para escolher qualquer cor.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _BarraMatiz(
                  matiz: atual.matiz ?? HSLColor.fromColor(atual.claro).hue,
                  ativa: atual.ehPersonalizada,
                  brilho: tema.brightness,
                  onMudar: (m) => controller.definirCor(CorDestaque.personalizada(m), salvar: false),
                  onFim: (m) => controller.definirCor(CorDestaque.personalizada(m)),
                ),
                const SizedBox(height: 28),
                Text('Prévia', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                _Previa(),
                const SizedBox(height: 16),
                if (atual != CorDestaque.padrao)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => controller.definirCor(CorDestaque.padrao),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Voltar ao verde padrão'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BolinhaCor extends StatelessWidget {
  final Color cor;
  final String nome;
  final bool selecionada;
  final VoidCallback onTap;

  const _BolinhaCor({required this.cor, required this.nome, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Semantics(
      button: true,
      selected: selecionada,
      label: 'Cor $nome',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selecionada ? cor : Colors.transparent, width: 2.5),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                  child: selecionada
                      ? Icon(
                          Icons.check_rounded,
                          color: ThemeData.estimateBrightnessForColor(cor) == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nome,
                style: tema.textTheme.labelSmall?.copyWith(
                  color: selecionada ? esquema.onSurface : esquema.onSurfaceVariant,
                  fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra com o arco-íris; tocar ou arrastar escolhe o matiz.
class _BarraMatiz extends StatelessWidget {
  final double matiz;
  final bool ativa;
  final Brightness brilho;
  final ValueChanged<double> onMudar;
  final ValueChanged<double> onFim;

  const _BarraMatiz({
    required this.matiz,
    required this.ativa,
    required this.brilho,
    required this.onMudar,
    required this.onFim,
  });

  static const _altura = 36.0;
  static const _tamanhoMarcador = 30.0;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cores = [
      for (var h = 0; h <= 360; h += 30) CorDestaque.personalizada(h.toDouble()).para(brilho),
    ];

    return LayoutBuilder(
      builder: (context, restricoes) {
        final largura = restricoes.maxWidth;
        final util = largura - _tamanhoMarcador;
        double matizEm(double x) => ((x - _tamanhoMarcador / 2) / util * 360).clamp(0, 360).toDouble();
        final posicao = matiz / 360 * util;

        return Semantics(
          slider: true,
          label: 'Cor personalizada',
          value: '${matiz.round()} graus',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => onFim(matizEm(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) => onMudar(matizEm(d.localPosition.dx)),
            onHorizontalDragEnd: (_) => onFim(matiz),
            child: SizedBox(
              height: _altura,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    left: _tamanhoMarcador / 2 - 6,
                    right: _tamanhoMarcador / 2 - 6,
                    top: 6,
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: cores),
                      ),
                    ),
                  ),
                  Positioned(
                    left: posicao,
                    child: Container(
                      width: _tamanhoMarcador,
                      height: _tamanhoMarcador,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CorDestaque.personalizada(matiz).para(brilho),
                        border: Border.all(color: ativa ? esquema.onSurface : Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mostra como os elementos principais ficam com a cor escolhida.
class _Previa extends StatelessWidget {

  const _Previa();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: esquema.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fitness_center_rounded, color: esquema.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treino A', style: tema.textTheme.titleMedium),
                    Text(
                      '8 séries · 45 min',
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(value: true, onChanged: (_) {}),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(value: 0.65, minHeight: 8),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar treino'),
          ),
        ],
      ),
    );
  }
}
