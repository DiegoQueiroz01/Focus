import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda no aparelho as séries já marcadas de uma sessão em andamento,
/// para que o progresso não se perca se o app for fechado no meio do treino.
class ProgressoSessaoStorage {
  ProgressoSessaoStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static final ProgressoSessaoStorage instance = ProgressoSessaoStorage();

  final FlutterSecureStorage _storage;

  String _chave(int sessaoId) => 'focus_sessao_$sessaoId';

  Future<Map<String, dynamic>?> ler(int sessaoId) async {
    try {
      final bruto = await _storage.read(key: _chave(sessaoId));
      return bruto == null ? null : jsonDecode(bruto) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> salvar(int sessaoId, Map<String, dynamic> progresso) async {
    try {
      await _storage.write(key: _chave(sessaoId), value: jsonEncode(progresso));
    } catch (_) {
      // Melhor esforço: sem armazenamento, o treino segue normalmente.
    }
  }

  Future<void> apagar(int sessaoId) async {
    try {
      await _storage.delete(key: _chave(sessaoId));
    } catch (_) {}
  }
}
