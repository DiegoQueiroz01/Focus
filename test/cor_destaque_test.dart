import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/theme/cor_destaque.dart';

void main() {
  group('CorDestaque', () {
    test('cores prontas voltam iguais depois de salvas', () {
      for (final cor in CorDestaque.prontas) {
        expect(CorDestaque.desserializar(cor.serializar()), cor);
      }
    });

    test('cor personalizada guarda o matiz', () {
      final cor = CorDestaque.desserializar(CorDestaque.personalizada(210).serializar());
      expect(cor.ehPersonalizada, isTrue);
      expect(cor.matiz, 210);
    });

    test('valor vazio ou estranho volta para o verde', () {
      expect(CorDestaque.desserializar(null), CorDestaque.verde);
      expect(CorDestaque.desserializar('xyz'), CorDestaque.verde);
      expect(CorDestaque.desserializar('h:abc'), CorDestaque.verde);
    });

    test('tema usa a cor escolhida em cada modo', () {
      final claro = AppTheme.construir(Brightness.light, CorDestaque.roxo);
      final escuro = AppTheme.construir(Brightness.dark, CorDestaque.roxo);
      expect(claro.colorScheme.primary, CorDestaque.roxo.claro);
      expect(escuro.colorScheme.primary, CorDestaque.roxo.escuro);
      // Fundo continua neutro (preto no escuro), só o destaque muda.
      expect(escuro.colorScheme.surface, AppTheme.escuro.colorScheme.surface);
    });

    test('texto sobre cor clara fica escuro', () {
      final tema = AppTheme.construir(Brightness.dark, CorDestaque.amarelo);
      expect(ThemeData.estimateBrightnessForColor(tema.colorScheme.onPrimary), Brightness.dark);
    });
  });
}
