import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda a escolha de tema (claro/escuro) no aparelho.
/// Enquanto o usuário não escolher, o app segue o tema do sistema.
class TemaController extends ValueNotifier<ThemeMode> {
  TemaController({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        super(ThemeMode.system);

  static final TemaController instance = TemaController();
  static const _chave = 'focus_tema';

  final FlutterSecureStorage _storage;

  Future<void> carregar() async {
    try {
      final salvo = await _storage.read(key: _chave);
      value = switch (salvo) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Sem acesso ao armazenamento: fica no tema do sistema.
    }
  }

  Future<void> definirEscuro(bool escuro) async {
    value = escuro ? ThemeMode.dark : ThemeMode.light;
    try {
      await _storage.write(key: _chave, value: escuro ? 'dark' : 'light');
    } catch (_) {
      // A troca vale para esta execução mesmo que não seja salva.
    }
  }
}
