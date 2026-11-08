import 'package:flutter/material.dart';

/// Campo de senha com botão para mostrar/ocultar o texto.
class CampoSenha extends StatefulWidget {
  final TextEditingController controller;
  final String rotulo;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;

  const CampoSenha({
    super.key,
    required this.controller,
    this.rotulo = 'Senha',
    this.autofillHints,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.helperText,
  });

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _visivel = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visivel,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.rotulo,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _visivel ? 'Ocultar senha' : 'Mostrar senha',
          icon: Icon(_visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visivel = !_visivel),
        ),
      ),
    );
  }
}
