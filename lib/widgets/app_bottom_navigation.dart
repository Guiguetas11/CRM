import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/all_movies_screen.dart';
import '../screens/all_series_screen.dart';
import '../screens/iframerplayer.dart';
import '../services/favorites_notifier.dart';

const Color _backgroundColor = Color(0xFF141414);
const Color _primaryColor = Color.fromARGB(255, 108, 9, 229); // Cor padrão (Home/Sair)

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final bool isMobile;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.isMobile,
  });

  // --- LÓGICA DE COR DINÂMICA ADICIONADA AQUI ---
  Color get _selectedColor {
    switch (currentIndex) {
      case 1: // Filmes
        return const Color(0xFFFF5252);
      case 2: // Séries
        return const Color(0xFF00E5FF);
      case 3: // TV ao Vivo
        return Colors.lightGreen;
      default: // Home (0) e Sair (4) usam a cor original
        return _primaryColor;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Sair',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Deseja realmente sair da sua conta?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00E5FF),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userEmail');
        await prefs.remove('userName');
        await prefs.setBool('isLoggedIn', false);

        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        print('Erro ao fazer logout: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: _backgroundColor.withOpacity(0.95),
      unselectedItemColor: Colors.white54,
      
      // --- AQUI APLICAMOS A VARIÁVEL DE COR ---
      selectedItemColor: _selectedColor, 
      
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) async {
        switch (index) {
          case 0: // Home
            Navigator.of(context).popUntil((route) => route.isFirst);
            break;
            
          case 1: // Filmes
            if (currentIndex != 1) {
              await context.read<FavoritesNotifier>().loadAll();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AllMoviesScreen(isMobile: isMobile),
                ),
              );
            }
            break;
            
          case 2: // Séries
            if (currentIndex != 2) {
              await context.read<FavoritesNotifier>().loadAll();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AllSeriesScreen(isMobile: isMobile),
                ),
              );
            }
            break;
            
          case 3: // TV ao Vivo
            if (currentIndex != 3) {
              await context.read<FavoritesNotifier>().loadAll();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const IframePlayerRoute(),
                ),
              );
            }
            break;
            
          case 4: // Sair
            _logout(context);
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Filmes'),
        BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Séries'),
        BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'TV ao Vivo'),
        BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sair'),
      ],
    );
  }
}