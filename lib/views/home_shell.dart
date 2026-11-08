import 'package:flutter/material.dart';
import 'package:focus/models/usuario.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/service/tema_controller.dart';
import 'package:focus/views/dashboard_screen.dart';
import 'package:focus/views/gps_screen.dart';
import 'package:focus/views/login_screen.dart';
import 'package:focus/views/treinos_screen.dart';
import 'package:focus/widgets/avatar_usuario.dart';

enum Destino {
  inicio('Início', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  treinos('Treinos', Icons.fitness_center_outlined, Icons.fitness_center_rounded),
  gps('GPS', Icons.route_outlined, Icons.route_rounded);

  final String rotulo;
  final IconData icone;
  final IconData iconeSelecionado;

  const Destino(this.rotulo, this.icone, this.iconeSelecionado);
}

/// Estrutura principal depois do login: menu lateral (☰) e a tela escolhida nele.
class HomeShell extends StatefulWidget {
  final Destino inicial;

  const HomeShell({super.key, this.inicial = Destino.inicio});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late Destino _destino = widget.inicial;

  void abrirMenu() => _scaffoldKey.currentState?.openDrawer();

  void irPara(Destino destino) {
    _scaffoldKey.currentState?.closeDrawer();
    if (destino != _destino) setState(() => _destino = destino);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _MenuLateral(atual: _destino, onSelecionar: irPara),
      // Cada tela é recriada ao ser escolhida, então sempre abre com dados atualizados.
      body: switch (_destino) {
        Destino.inicio => const PainelInicio(key: ValueKey(Destino.inicio)),
        Destino.treinos => const TreinoScreen(key: ValueKey(Destino.treinos)),
        Destino.gps => const GpsScreen(key: ValueKey(Destino.gps)),
      },
    );
  }
}

/// Ícone ☰ usado no canto superior esquerdo das telas principais.
class BotaoMenu extends StatelessWidget {
  const BotaoMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onPressed: () => context.findAncestorStateOfType<HomeShellState>()?.abrirMenu(),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  final Destino atual;
  final ValueChanged<Destino> onSelecionar;

  const _MenuLateral({required this.atual, required this.onSelecionar});

  Future<void> _sair(BuildContext context) async {
    await ApiService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return NavigationDrawer(
      backgroundColor: esquema.surfaceContainerLowest,
      selectedIndex: Destino.values.indexOf(atual),
      onDestinationSelected: (i) => onSelecionar(Destino.values[i]),
      indicatorColor: esquema.primary.withValues(alpha: 0.14),
      children: [
        const _CabecalhoUsuario(),
        for (final destino in Destino.values)
          NavigationDrawerDestination(
            icon: Icon(destino.icone),
            selectedIcon: Icon(destino.iconeSelecionado, color: esquema.primary),
            label: Text(destino.rotulo),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Divider(),
        ),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: TemaController.instance,
          builder: (context, _, _) {
            final escuro = tema.brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SwitchListTile(
                shape: const StadiumBorder(),
                secondary: Icon(escuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                title: const Text('Tema escuro'),
                value: escuro,
                onChanged: TemaController.instance.definirEscuro,
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            shape: const StadiumBorder(),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sair'),
            onTap: () => _sair(context),
          ),
        ),
      ],
    );
  }
}

class _CabecalhoUsuario extends StatelessWidget {
  const _CabecalhoUsuario();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return FutureBuilder<Usuario>(
      future: ApiService.instance.getUsuario(),
      builder: (context, snapshot) {
        final usuario = snapshot.data;
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 20),
          child: Row(
            children: [
              AvatarUsuario(usuario: usuario),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario?.nome ?? 'Focus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    if (usuario?.email != null)
                      Text(
                        usuario!.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
