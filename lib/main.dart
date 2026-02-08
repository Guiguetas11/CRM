import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// IMPORT PARA FAVORITOS.
import 'package:provider/provider.dart';
import 'services/favorites_notifier.dart';

// Imports de webview_flutter e dart:io removidos, pois não são necessários para o Flutter Web.

import 'screens/loginscreen.dart';
import 'services/app_theme.dart';
import 'services/app_router.dart';
import 'services/sheets_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Lógica de inicialização do WebView removida, pois o projeto é apenas Web.
  // No Flutter Web, usamos HtmlElementView na tela do player, e não há
  // necessidade de inicializar as plataformas nativas aqui.
  // ------------------------------------------------------------------

  // Inicializa Hive e SheetsService
  final sheetsService = await SheetsService.create();
  await Hive.initFlutter();

  // Define orientação e modo imersivo
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    ChangeNotifierProvider(
      create: (_) => FavoritesNotifier()..loadAll(),
      child: MyWebApp(sheetsService: sheetsService),
    ),
  );
}

class MyWebApp extends StatelessWidget {
  final SheetsService sheetsService;
  const MyWebApp({super.key, required this.sheetsService});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(sheetsService);

    return MaterialApp(
      title: 'VibesCines',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.appThemeData[AppTheme.darkTheme],
      initialRoute: LoginScreen.id,
      onGenerateRoute: appRouter.onGenerateRoute,
    );
  }
}