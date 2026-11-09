import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:focus/theme/cor_destaque.dart';

/// Guarda a aparência escolhida no aparelho: tema (claro/escuro) e cor de destaque.
/// Enquanto o usuário não escolher, o app segue o tema do sistema e usa o verde.
class TemaController extends ChangeNotifier {
  TemaController({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static final TemaController instance = TemaController();
  static const _chaveModo = 'focus_tema';
  static const _chaveCor = 'focus_cor_destaque';

  final FlutterSecureStorage _storage;

  ThemeMode _modo = ThemeMode.system;
  CorDestaque _cor = CorDestaque.padrao;

  ThemeMode get modo => _modo;
  CorDestaque get cor => _cor;

  Future<void> carregar() async {
    try {
      final modo = await _storage.read(key: _chaveModo);
      final cor = await _storage.read(key: _chaveCor);
      _modo = switch (modo) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _cor = CorDestaque.desserializar(cor);
      notifyListeners();
    } catch (_) {
      // Sem acesso ao armazenamento: fica com o padrão.
    }
  }

  Future<void> definirEscuro(bool escuro) async {
    _modo = escuro ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _salvar(_chaveModo, escuro ? 'dark' : 'light');
  }

  /// Troca a cor na hora. Use [salvar] = false enquanto o usuário arrasta o seletor.
  Future<void> definirCor(CorDestaque cor, {bool salvar = true}) async {
    if (cor != _cor) {
      _cor = cor;
      notifyListeners();
    }
    if (salvar) await _salvar(_chaveCor, cor.serializar());
  }

  Future<void> _salvar(String chave, String valor) async {
    try {
      await _storage.write(key: chave, value: valor);
    } catch (_) {
      // A troca vale para esta execução mesmo que não seja salva.
    }
  }
}
