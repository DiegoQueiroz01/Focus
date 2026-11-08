import 'package:flutter/material.dart';
import 'package:focus/models/catalogo_exercicio.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/imagem_exercicio.dart';
import 'package:focus/widgets/mapa_muscular.dart';

/// Detalhes de um exercício do catálogo: fotos, músculos trabalhados e como fazer.
/// Com [podeAdicionar], mostra o botão "Adicionar ao treino" e retorna o exercício ao tocar.
class ExercicioCatalogoScreen extends StatefulWidget {
  final String id;
  final CatalogoExercicio? resumo;
  final bool podeAdicionar;

  const ExercicioCatalogoScreen({super.key, required this.id, this.resumo, this.podeAdicionar = false});

  @override
  State<ExercicioCatalogoScreen> createState() => _ExercicioCatalogoScreenState();
}

class _ExercicioCatalogoScreenState extends State<ExercicioCatalogoScreen> {
  late Future<CatalogoExercicio> _detalhe = ApiService.instance.getExercicioCatalogo(widget.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogoExercicio>(
      future: _detalhe,
      builder: (context, snapshot) {
        final exercicio = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(exercicio?.nome ?? widget.resumo?.nome ?? '')),
          body: switch (snapshot) {
            AsyncSnapshot(hasError: true) => EstadoVazio(
                icone: Icons.cloud_off_rounded,
                titulo: 'Não foi possível carregar',
                mensagem: snapshot.error.toString(),
                rotuloAcao: 'Tentar novamente',
                onAcao: () => setState(() => _detalhe = ApiService.instance.getExercicioCatalogo(widget.id)),
              ),
            _ when exercicio == null => const Center(child: CircularProgressIndicator()),
            _ => _Conteudo(exercicio: exercicio),
          },
          bottomNavigationBar: widget.podeAdicionar && exercicio != null
              ? SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, exercicio),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar ao treino'),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _Conteudo extends StatelessWidget {
  final CatalogoExercicio exercicio;

  const _Conteudo({required this.exercicio});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final secundario = esquema.onSurfaceVariant;

    final etiquetas = [
      exercicio.tipo.rotulo,
      if (exercicio.equipamento != null) exercicio.equipamento!,
      if (exercicio.nivelRotulo != null) exercicio.nivelRotulo!,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _GaleriaFotos(exercicio: exercicio),
        const SizedBox(height: 20),
        Text(exercicio.nome, style: tema.textTheme.headlineSmall),
        if (exercicio.nomeIngles != null)
          Text(exercicio.nomeIngles!, style: tema.textTheme.bodyMedium?.copyWith(color: secundario)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final etiqueta in etiquetas)
              Chip(label: Text(etiqueta), visualDensity: VisualDensity.compact),
          ],
        ),
        if (exercicio.descricao != null) ...[
          const SizedBox(height: 16),
          Text(exercicio.descricao!, style: tema.textTheme.bodyLarge),
        ],
        const SizedBox(height: 28),
        const _Titulo('Músculos trabalhados'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapaMuscular(
                  principais: exercicio.musculosPrincipais.toSet(),
                  secundarios: exercicio.musculosSecundarios.toSet(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Frente', style: tema.textTheme.labelSmall?.copyWith(color: secundario)),
                    Text('Costas', style: tema.textTheme.labelSmall?.copyWith(color: secundario)),
                  ],
                ),
                const SizedBox(height: 16),
                _ListaMusculos(
                  cor: esquema.primary,
                  rotulo: 'Principais',
                  musculos: exercicio.musculosPrincipais,
                ),
                if (exercicio.musculosSecundarios.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ListaMusculos(
                    cor: esquema.primary.withValues(alpha: 0.35),
                    rotulo: 'Secundários',
                    musculos: exercicio.musculosSecundarios,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (exercicio.instrucoes.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _Titulo('Como fazer'),
          const SizedBox(height: 12),
          for (final (i, passo) in exercicio.instrucoes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: esquema.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text('${i + 1}', style: tema.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(passo, style: tema.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          exercicio.nomeIngles != null
              ? 'Fotos e instruções: free-exercise-db (domínio público).'
              : 'Atividade do catálogo Focus.',
          style: tema.textTheme.labelSmall?.copyWith(color: secundario),
        ),
      ],
    );
  }
}

class _GaleriaFotos extends StatefulWidget {
  final CatalogoExercicio exercicio;

  const _GaleriaFotos({required this.exercicio});

  @override
  State<_GaleriaFotos> createState() => _GaleriaFotosState();
}

class _GaleriaFotosState extends State<_GaleriaFotos> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final fotos = widget.exercicio.imagensUrl;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    if (fotos.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: ImagemExercicio(icone: widget.exercicio.icone, raio: 20),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            itemCount: fotos.length,
            onPageChanged: (p) => setState(() => _pagina = p),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ImagemExercicio(url: fotos[i], raio: 20, ajuste: BoxFit.contain),
            ),
          ),
        ),
        if (fotos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _pagina == 0 ? 'Posição inicial' : 'Posição final',
                style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              for (var i = 0; i < fotos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _pagina ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _pagina ? esquema.primary : esquema.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ListaMusculos extends StatelessWidget {
  final Color cor;
  final String rotulo;
  final List<String> musculos;

  const _ListaMusculos({required this.cor, required this.rotulo, required this.musculos});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$rotulo: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: musculos.map(rotuloMusculo).join(', ')),
            ]),
            style: tema.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Text(
      texto.toUpperCase(),
      style: tema.textTheme.labelMedium?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
