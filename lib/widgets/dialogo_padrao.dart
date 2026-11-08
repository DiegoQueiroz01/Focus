import 'package:flutter/material.dart';

/// Diálogo com o layout padrão do app: ícone opcional, título, conteúdo e botões
/// empilhados, ocupando toda a largura e com o texto centralizado.
class DialogoPadrao extends StatelessWidget {
  final IconData? icone;
  final String titulo;
  final Widget? conteudo;
  final String rotuloPrincipal;
  final VoidCallback? onPrincipal;
  final String? rotuloSecundario;
  final VoidCallback? onSecundario;

  /// Pinta o botão principal com a cor de erro (excluir, descartar).
  final bool destrutivo;

  const DialogoPadrao({
    super.key,
    this.icone,
    required this.titulo,
    this.conteudo,
    required this.rotuloPrincipal,
    this.onPrincipal,
    this.rotuloSecundario,
    this.onSecundario,
    this.destrutivo = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 36, color: destrutivo ? esquema.error : esquema.primary),
                const SizedBox(height: 12),
              ],
              Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
              if (conteudo != null) ...[
                const SizedBox(height: 12),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  child: conteudo!,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onPrincipal,
                style: destrutivo
                    ? FilledButton.styleFrom(backgroundColor: esquema.error, foregroundColor: esquema.onError)
                    : null,
                child: Text(rotuloPrincipal, textAlign: TextAlign.center),
              ),
              if (rotuloSecundario != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSecundario ?? () => Navigator.pop(context),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(rotuloSecundario!, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pergunta de sim/não. Retorna true só se o usuário confirmar.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String rotuloConfirmar,
  String rotuloCancelar = 'Cancelar',
  IconData? icone,
  bool destrutivo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (context) => DialogoPadrao(
      icone: icone,
      titulo: titulo,
      conteudo: Text(mensagem),
      rotuloPrincipal: rotuloConfirmar,
      onPrincipal: () => Navigator.pop(context, true),
      rotuloSecundario: rotuloCancelar,
      onSecundario: () => Navigator.pop(context, false),
      destrutivo: destrutivo,
    ),
  );
  return resposta ?? false;
}
