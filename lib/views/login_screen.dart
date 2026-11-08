import 'package:flutter/material.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/validadores.dart';
import 'package:focus/views/cadastro_screen.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/widgets/campo_senha.dart';

class LoginScreen extends StatefulWidget {
  final bool sessaoExpirada;

  const LoginScreen({super.key, this.sessaoExpirada = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessaoExpirada) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarErro('Sua sessão expirou. Faça login novamente.');
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await ApiService.instance.login(_emailController.text.trim(), _senhaController.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShell()),
      );
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _abrirCadastro() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: esquema.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.center_focus_strong_rounded, color: esquema.onPrimary, size: 28),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('Focus', style: tema.textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Entre para acompanhar seus treinos.',
                        style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                      const SizedBox(height: 36),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: validarObrigatorio,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CampoSenha(
                        controller: _senhaController,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _fazerLogin(),
                        validator: validarObrigatorio,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _enviando ? null : _fazerLogin,
                        child: _enviando
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: esquema.onSurfaceVariant,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Ainda não tem conta?', style: TextStyle(color: esquema.onSurfaceVariant)),
                          TextButton(
                            onPressed: _enviando ? null : _abrirCadastro,
                            child: const Text('Criar conta'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
