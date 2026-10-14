import 'package:flutter/material.dart';
import 'package:focus/views/dashboard_screen.dart';
import 'package:focus/service/json_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  void _fazerLogin() async {
    String name = _usernameController.text;
    String senha = _senhaController.text;

    final jsonService = JsonService();
    List<dynamic> listaUsuarios = await jsonService.lerUsuarios();

    bool usuarioEncontrado = false;

    for (var usuario in listaUsuarios) {
      if ((usuario['nome'] == name) && usuario['senha'] == senha) {
        usuarioEncontrado = true;
        break;
      }
    }

    if (usuarioEncontrado) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome ou senha inválidos!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _entrarSemLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 59, 249, 66),
              ),
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