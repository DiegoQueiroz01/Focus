import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focus/models/dieta.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/utils/formatadores.dart';
import 'package:focus/widgets/dialogo_padrao.dart';
import 'package:focus/widgets/estado_vazio.dart';
import 'package:focus/widgets/grafico_peso.dart';
import 'package:focus/widgets/resumo_nutricional.dart';

/// Pergunta o peso de hoje e salva. Retorna true se salvou.
Future<bool> registrarPeso(BuildContext context, {double? atual}) async {
  final controller = TextEditingController(text: atual == null ? '' : atual.toStringAsFixed(1).replaceAll('.', ','));
  final peso = await showDialog<double>(
    context: context,
    builder: (context) {
      void confirmar() {
        final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
        if (v != null && v >= 30 && v <= 300) Navigator.pop(context, v);
      }

      return DialogoPadrao(
        icone: Icons.monitor_weight_outlined,
        titulo: 'Peso de hoje',
        conteudo: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Para comparar melhor, pese-se sempre no mesmo horário, de preferência ao acordar.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(suffixText: 'kg'),
              onSubmitted: (_) => confirmar(),
            ),
          ],
        ),
        rotuloPrincipal: 'Salvar',
        onPrincipal: confirmar,
        rotuloSecundario: 'Cancelar',
      );
    },
  );
  controller.dispose();
  if (peso == null || !context.mounted) return false;
  try {
    await ApiService.instance.registrarPeso(peso);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    return false;
  }
}

/// Evolução do peso: atual, variação, gráfico e histórico.
class PesoScreen extends StatefulWidget {
  const PesoScreen({super.key});

  @override
  State<PesoScreen> createState() => _PesoScreenState();
}

class _PesoScreenState extends State<PesoScreen> {
  late Future<(List<RegistroPeso>, PerfilNutricional)> _dados = _carregar();

  Future<(List<RegistroPeso>, PerfilNutricional)> _carregar() async {
    final api = ApiService.instance;
    final resultados = await Future.wait([api.getPesos(limite: 365), api.getPerfil()]);
    return (resultados[0] as List<RegistroPeso>, resultados[1] as PerfilNutricional);
  }

  Future<void> _recarregar() async {
    final novo = _carregar();
    setState(() {
      _dados = novo;
    });
    await novo.catchError((_) => (<RegistroPeso>[], const PerfilNutricional()));
  }

  Future<void> _registrar(double? atual) async {
    if (await registrarPeso(context, atual: atual) && mounted) await _recarregar();
  }

  Future<void> _excluir(RegistroPeso registro) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir registro?',
      mensagem: '${formatarPeso(registro.pesoKg)} em ${formatarDataRelativa(registro.data).toLowerCase()}.',
      rotuloConfirmar: 'Excluir',
      icone: Icons.delete_outline_rounded,
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    try {
      await ApiService.instance.excluirPeso(registro.id);
      await _recarregar();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return FutureBuilder<(List<RegistroPeso>, PerfilNutricional)>(
      future: _dados,
      builder: (context, snapshot) {
        final registros = snapshot.data?.$1;
        final perfil = snapshot.data?.$2;
        final atual = registros?.firstOrNull?.pesoKg;

        return Scaffold(
          appBar: AppBar(title: const Text('Peso')),
          floatingActionButton: registros == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _registrar(atual),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar peso'),
                ),
          body: Builder(
            builder: (context) {
              if (snapshot.hasError) {
                return EstadoVazio(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não foi possível carregar',
                  mensagem: snapshot.error.toString(),
                  rotuloAcao: 'Tentar novamente',
                  onAcao: _recarregar,
                );
              }
              if (registros == null) return const Center(child: CircularProgressIndicator());
              if (registros.isEmpty) {
                return EstadoVazio(
                  icone: Icons.monitor_weight_outlined,
                  titulo: 'Nenhum peso registrado',
                  mensagem: 'Registre seu peso para acompanhar a evolução e calcular calorias com precisão.',
                  rotuloAcao: 'Registrar peso',
                  onAcao: () => _registrar(null),
                );
              }

              final primeiro = registros.last;
              final variacao = atual! - primeiro.pesoKg;
              final meta = perfil?.pesoMetaKg;

              return RefreshIndicator(
                onRefresh: _recarregar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatarPeso(atual), style: tema.textTheme.headlineMedium),
                                const SizedBox(width: 12),
                                if (registros.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${variacao > 0 ? '+' : ''}${formatarPeso(variacao)} desde ${formatarDataRelativa(primeiro.data).toLowerCase()}',
                                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                                    ),
                                  ),
                              ],
                            ),
                            if (meta != null)
                              Text(
                                'Meta: ${formatarPeso(meta)} · faltam ${formatarPeso((meta - atual).abs())}',
                                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                              ),
                            const SizedBox(height: 16),
                            GraficoPeso(registros: registros.take(90).toList(), meta: meta, altura: 160),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Histórico', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          for (final (i, r) in registros.indexed) ...[
                            if (i > 0) const Divider(indent: 16, endIndent: 16),
                            ListTile(
                              title: Text(formatarPeso(r.pesoKg)),
                              subtitle: Text(formatarDataRelativa(r.data)),
                              trailing: _Diferenca(
                                kg: i + 1 < registros.length ? r.pesoKg - registros[i + 1].pesoKg : null,
                              ),
                              onLongPress: () => _excluir(r),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque e segure um registro para excluir.',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Diferenca extends StatelessWidget {
  final double? kg;

  const _Diferenca({this.kg});

  @override
  Widget build(BuildContext context) {
    final valor = kg;
    if (valor == null || valor.abs() < 0.05) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          valor > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 16,
          color: esquema.onSurfaceVariant,
        ),
        Text(formatarPeso(valor.abs()), style: TextStyle(color: esquema.onSurfaceVariant)),
      ],
    );
  }
}
