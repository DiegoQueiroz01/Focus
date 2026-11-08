import 'package:flutter/material.dart';
import 'package:focus/models/catalogo_exercicio.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/views/exercicio_catalogo_screen.dart';

/// Foto de um exercício do treino, buscada pelo [catalogoId]. Tocar abre os detalhes
/// do catálogo. Sem vínculo com o catálogo, mostra [semCatalogo].
class MiniaturaExercicio extends StatelessWidget {
  final String? catalogoId;
  final double tamanho;
  final Widget semCatalogo;
  final bool abreDetalhe;

  const MiniaturaExercicio({
    super.key,
    required this.catalogoId,
    required this.semCatalogo,
    this.tamanho = 48,
    this.abreDetalhe = true,
  });

  @override
  Widget build(BuildContext context) {
    final id = catalogoId;
    if (id == null) return semCatalogo;

    final imagem = FutureBuilder<CatalogoExercicio>(
      future: ApiService.instance.getExercicioCatalogo(id),
      builder: (context, snapshot) => ImagemExercicio(
        url: snapshot.data?.imagemUrl,
        icone: snapshot.data?.icone,
        largura: tamanho,
        altura: tamanho,
        raio: tamanho * 0.25,
      ),
    );
    if (!abreDetalhe) return imagem;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExercicioCatalogoScreen(id: id)),
      ),
      child: imagem,
    );
  }
}

/// Foto de referência do exercício. Sem foto (ou se ela não carregar), mostra um ícone.
class ImagemExercicio extends StatelessWidget {
  final String? url;
  final String? icone;
  final double? largura;
  final double? altura;
  final double raio;
  final BoxFit ajuste;

  const ImagemExercicio({
    super.key,
    this.url,
    this.icone,
    this.largura,
    this.altura,
    this.raio = 12,
    this.ajuste = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    Widget substituto({bool carregando = false}) => Container(
          color: esquema.surfaceContainer,
          alignment: Alignment.center,
          child: carregando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : LayoutBuilder(
                  builder: (context, restricoes) => Icon(
                    iconeDoCatalogo(icone),
                    color: esquema.primary,
                    size: (restricoes.biggest.shortestSide * 0.45).clamp(18, 72),
                  ),
                ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: SizedBox(
        width: largura,
        height: altura,
        child: url == null
            ? substituto()
            : Container(
                // As fotos têm fundo branco; o fundo claro evita bordas estranhas no tema escuro.
                color: Colors.white,
                child: Image.network(
                  url!,
                  fit: ajuste,
                  loadingBuilder: (context, filho, progresso) =>
                      progresso == null ? filho : substituto(carregando: true),
                  errorBuilder: (_, _, _) => substituto(),
                ),
              ),
      ),
    );
  }
}
