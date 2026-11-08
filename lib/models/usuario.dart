class Usuario {
  final int id;
  final String nome;
  final String? email;

  /// Foto de perfil (Gravatar do e-mail ou de um login social). Pode não existir.
  final String? fotoUrl;

  const Usuario({required this.id, required this.nome, this.email, this.fotoUrl});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: (json['id'] as num).toInt(),
      nome: (json['name'] ?? '').toString(),
      email: json['email'] as String?,
      fotoUrl: json['avatar_url'] as String?,
    );
  }

  String get primeiroNome {
    final partes = nome.trim().split(RegExp(r'\s+'));
    return partes.isEmpty ? '' : partes.first;
  }

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }
}
