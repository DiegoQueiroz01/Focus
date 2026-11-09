import 'package:flutter/material.dart';

/// Cor de destaque do app (botões, ícones selecionados, gráficos...).
/// Cada cor tem uma versão para o tema claro e outra, mais viva, para o escuro.
class CorDestaque {
  final String id;
  final String nome;
  final Color claro;
  final Color escuro;

  /// Matiz (0–360) quando a cor foi montada pelo usuário; nulo nas cores prontas.
  final double? matiz;

  const CorDestaque._(this.id, this.nome, this.claro, this.escuro, [this.matiz]);

  static const verde = CorDestaque._('verde', 'Verde', Color(0xFF16A34A), Color(0xFF4ADE80));
  static const azul = CorDestaque._('azul', 'Azul', Color(0xFF2563EB), Color(0xFF60A5FA));
  static const ciano = CorDestaque._('ciano', 'Ciano', Color(0xFF0891B2), Color(0xFF22D3EE));
  static const roxo = CorDestaque._('roxo', 'Roxo', Color(0xFF7C3AED), Color(0xFFA78BFA));
  static const rosa = CorDestaque._('rosa', 'Rosa', Color(0xFFDB2777), Color(0xFFF472B6));
  static const vermelho = CorDestaque._('vermelho', 'Vermelho', Color(0xFFDC2626), Color(0xFFF87171));
  static const laranja = CorDestaque._('laranja', 'Laranja', Color(0xFFEA580C), Color(0xFFFB923C));
  static const amarelo = CorDestaque._('amarelo', 'Amarelo', Color(0xFFCA8A04), Color(0xFFFACC15));

  static const padrao = verde;
  static const prontas = [verde, azul, ciano, roxo, rosa, vermelho, laranja, amarelo];

  /// Cor livre a partir de um matiz do arco-íris (0 = vermelho, 120 = verde, 240 = azul).
  factory CorDestaque.personalizada(double matiz) {
    final m = matiz.clamp(0, 360).toDouble();
    return CorDestaque._(
      'personalizada',
      'Personalizada',
      HSLColor.fromAHSL(1, m, 0.75, 0.42).toColor(),
      HSLColor.fromAHSL(1, m, 0.85, 0.65).toColor(),
      m,
    );
  }

  bool get ehPersonalizada => matiz != null;

  Color para(Brightness brilho) => brilho == Brightness.dark ? escuro : claro;

  /// Texto salvo no aparelho: o id da cor pronta ou `h:<matiz>`.
  String serializar() => ehPersonalizada ? 'h:${matiz!.toStringAsFixed(0)}' : id;

  static CorDestaque desserializar(String? valor) {
    if (valor == null) return padrao;
    if (valor.startsWith('h:')) {
      final matiz = double.tryParse(valor.substring(2));
      return matiz == null ? padrao : CorDestaque.personalizada(matiz);
    }
    return prontas.firstWhere((c) => c.id == valor, orElse: () => padrao);
  }

  @override
  bool operator ==(Object other) => other is CorDestaque && other.serializar() == serializar();

  @override
  int get hashCode => serializar().hashCode;
}
