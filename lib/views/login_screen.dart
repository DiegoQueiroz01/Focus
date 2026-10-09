import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  void _fazerLogin() {
    String name = _usernameController.text;
    String senha = _senhaController.text;

    if (name == 'user' && senha == 'admin') {
      print('Bem-vindo!');
    } else {
      print('Acesso negado. Usuário ou senha incorretos.');
    }
  }

  void _entrarSemLogin() {
    print('Acessando como visitante. Alguns recursos são limitados nesse modo.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - Focus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senhaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fazerLogin,
              child: const Text('Entrar'),
            ),
            TextButton(
              onPressed: _entrarSemLogin,
              child: const Text('Entrar sem Login'),
            ),
          ],
        ),
      ),
    );
  }
}