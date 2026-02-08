import 'package:flutter/material.dart';

import '../screens/loginscreen.dart';
import '../screens/pgvendas_screen.dart';
import '../screens/vip_login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/iframerplayer.dart';

import '../services/sheets_service.dart';


class AppRouter {
  final SheetsService sheetsService;

  AppRouter(this.sheetsService);

  Route? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case LoginScreen.id:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case LoginVipScreen.id:
        return MaterialPageRoute(
          builder: (_) => LoginVipScreen(sheetsService: sheetsService),
        );

      case IframePlayerRoute.id: // ✅ ROTA REGISTRADA
        return MaterialPageRoute(
          builder: (_) => const IframePlayerRoute(),
        );

      case HomeScreen.id:
        // Se quiser passar dados ao navegar: Navigator.pushNamed(context, HomeScreen.id, arguments: {'userEmail': 'email@exemplo.com', 'userName': 'João'});
        final args = settings.arguments;
        String userEmail = '';
        String userName = 'Usuário VIP';

        if (args != null && args is Map) {
          if (args['userEmail'] != null && args['userEmail'] is String) {
            userEmail = args['userEmail'] as String;
          }
          if (args['userName'] != null && args['userName'] is String) {
            userName = args['userName'] as String;
          }
        }

        return MaterialPageRoute(
          builder: (context) => HomeScreen(
            isMobile: MediaQuery.of(context).size.width < 600,
            userName: userName,
            userEmail: userEmail,
          ),
        );

      case VipPaymentScreen.id:
        return MaterialPageRoute(builder: (_) => VipPaymentScreen());

      default:
        return null;
    }
  }
}
