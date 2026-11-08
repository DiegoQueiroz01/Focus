import 'package:flutter/material.dart';
import 'package:focus/models/usuario.dart';

/// Foto de perfil do usuário. Enquanto carrega, ou se não houver foto, mostra as iniciais.
class AvatarUsuario extends StatelessWidget {
  final Usuario? usuario;
  final double raio;

  const AvatarUsuario({super.key, required this.usuario, this.raio = 22});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final url = usuario?.fotoUrl;

    return CircleAvatar(
      radius: raio,
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      // A foto é desenhada por cima das iniciais; se falhar (ex.: e-mail sem Gravatar),
      // o erro é ignorado e as iniciais continuam visíveis.
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        usuario?.iniciais ?? '',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: raio * 0.7),
      ),
    );
  }
}
