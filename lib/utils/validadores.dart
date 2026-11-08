final _formatoEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validarObrigatorio(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'Campo obrigatório' : null;

/// Checagem rápida de formato. A API ainda confirma se o domínio existe.
String? validarEmail(String? valor) {
  final email = valor?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail';
  if (!_formatoEmail.hasMatch(email)) return 'E-mail inválido';
  return null;
}

String? validarNome(String? valor) {
  final nome = valor?.trim() ?? '';
  if (nome.isEmpty) return 'Informe seu nome';
  if (nome.length < 2) return 'Nome muito curto';
  return null;
}

String? validarSenhaNova(String? valor) {
  final senha = valor ?? '';
  if (senha.isEmpty) return 'Crie uma senha';
  if (senha.length < 8) return 'Use pelo menos 8 caracteres';
  if (senha.length > 72) return 'Use no máximo 72 caracteres';
  return null;
}
