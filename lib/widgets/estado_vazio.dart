import 'package:flutter/material.dart';

/// Mensagem centralizada para listas vazias ou erros, com ação opcional.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? mensagem;
  final String? rotuloAcao;
  final VoidCallback? onAcao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.rotuloAcao,
    this.onAcao,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: esquema.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icone, size: 30, color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(titulo, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
            if (mensagem != null) ...[
              const SizedBox(height: 6),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
            if (rotuloAcao != null && onAcao != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAcao, child: Text(rotuloAcao!)),
            ],
          ],
        ),
      ),
    );
  }
}
