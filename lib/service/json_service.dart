import 'dart:convert';
import 'package:flutter/services.dart';

class JsonService {
  Future<List<dynamic>> lerUsuarios() async {
    try {
      final String resposta = await rootBundle.loadString('assets/data/usuarios.json');
      final Map<String, dynamic> dados = jsonDecode(resposta);
      return dados['usuarios'] as List<dynamic>;
    } catch (e) {
      print('Erro ao carregar usuários: $e');
      return [];
    }
  }

  Future<List<dynamic>> lerTreinos() async {
    try {
      final String resposta = await rootBundle.loadString('assets/data/treinos.json');
      final Map<String, dynamic> dados = jsonDecode(resposta);
      return dados['historico_treinos'] as List<dynamic>;
    } catch (e) {
      print('Erro ao carregar treinos: $e');
      return [];
    }
  }
}