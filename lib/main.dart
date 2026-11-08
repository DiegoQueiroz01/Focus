import 'package:flutter/material.dart';
import 'package:focus/service/api_service.dart';
import 'package:focus/service/tema_controller.dart';
import 'package:focus/theme/app_theme.dart';
import 'package:focus/views/home_shell.dart';
import 'package:focus/views/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TemaController.instance.carregar();

  ApiService.instance.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen(sessaoExpirada: true)),
      (_) => false,
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaController.instance,
      builder: (context, modo, _) => MaterialApp(
        title: 'Focus',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        darkTheme: AppTheme.escuro,
        themeMode: modo,
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide a tela inicial com base no token salvo no dispositivo.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.instance.isAuthenticated(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomeShell() : const LoginScreen();
      },
    );
  }
}
