import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  // Chaves unificadas para armazenamento no SharedPreferences
  static const String FAVORITE_MOVIES_KEY = 'favorites_movies_v2';
  static const String FAVORITE_SERIES_KEY = 'favorites_series_v2';
  static const String FAVORITE_CHANNELS_KEY = 'favorites_channels_v2';

  // Flag para indicar se a migração já foi executada
  static const String MIGRATION_DONE_KEY = 'favorites_migration_done';

  /// Migra favoritos antigos para o novo formato
  static Future<void> migrateLegacyFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verifica se a migração já foi feita
      final migrationDone = prefs.getBool(MIGRATION_DONE_KEY) ?? false;
      if (migrationDone) {
        print('Migração de favoritos já foi realizada anteriormente.');
        return;
      }

      print('Iniciando migração de favoritos...');
      
      // Conjuntos para armazenar os favoritos migrados
      final Set<String> migratedMovies = {};
      final Set<String> migratedSeries = {};
      final Set<String> migratedChannels = {};

      // Carrega favoritos existentes no novo formato
      final existingMovies = await loadFavorites(FAVORITE_MOVIES_KEY);
      final existingSeries = await loadFavorites(FAVORITE_SERIES_KEY);
      final existingChannels = await loadFavorites(FAVORITE_CHANNELS_KEY);

      migratedMovies.addAll(existingMovies);
      migratedSeries.addAll(existingSeries);
      migratedChannels.addAll(existingChannels);

      // Migra favoritos antigos (formato: 'fav_movie_TITULO' ou 'fav_TITULO')
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('fav_movie_')) {
          final title = key.replaceFirst('fav_movie_', '');
          final isFavorite = prefs.getBool(key) ?? false;
          if (isFavorite) {
            migratedMovies.add(title);
            print('Migrado filme: $title');
          }
          // Remove a chave antiga
          await prefs.remove(key);
        } else if (key.startsWith('fav_') && !key.startsWith('fav_movie_')) {
          final title = key.replaceFirst('fav_', '');
          final isFavorite = prefs.getBool(key) ?? false;
          if (isFavorite) {
            // Assume que é filme se não especificado
            migratedMovies.add(title);
            print('Migrado (assumido filme): $title');
          }
          // Remove a chave antiga
          await prefs.remove(key);
        }
      }

      // Migra favoritos de canais (formato antigo: 'tv_favorites')
      final oldChannelFavorites = prefs.getStringList('tv_favorites');
      if (oldChannelFavorites != null) {
        migratedChannels.addAll(oldChannelFavorites);
        print('Migrados ${oldChannelFavorites.length} canais');
        // Remove a chave antiga
        await prefs.remove('tv_favorites');
      }

      // Salva os favoritos migrados no novo formato
      await saveFavorites(FAVORITE_MOVIES_KEY, migratedMovies);
      await saveFavorites(FAVORITE_SERIES_KEY, migratedSeries);
      await saveFavorites(FAVORITE_CHANNELS_KEY, migratedChannels);

      // Marca a migração como concluída
      await prefs.setBool(MIGRATION_DONE_KEY, true);

      print('Migração concluída:');
      print('- Filmes: ${migratedMovies.length}');
      print('- Séries: ${migratedSeries.length}');
      print('- Canais: ${migratedChannels.length}');
    } catch (e) {
      print('Erro durante a migração de favoritos: $e');
    }
  }

  /// Carrega a lista de favoritos (títulos/nomes) para uma chave específica.
  static Future<Set<String>> loadFavorites(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // O Set garante que não haverá duplicatas
      final favoritesList = prefs.getStringList(key) ?? [];
      return favoritesList.toSet();
    } catch (e) {
      print('Erro ao carregar favoritos para $key: $e');
      return {};
    }
  }

  /// Salva a lista de favoritos para uma chave específica.
  static Future<void> saveFavorites(String key, Set<String> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, favorites.toList());
      print('Salvos ${favorites.length} favoritos em $key');
    } catch (e) {
      print('Erro ao salvar favoritos para $key: $e');
    }
  }

  /// Adiciona ou remove um item dos favoritos e salva o estado.
  /// Retorna o novo estado (true se for favorito, false caso contrário).
  static Future<bool> toggleFavorite(String key, String contentId) async {
    final favorites = await loadFavorites(key);
    bool isAdding;

    if (favorites.contains(contentId)) {
      favorites.remove(contentId);
      isAdding = false;
      print('Removido de favoritos: $contentId');
    } else {
      favorites.add(contentId);
      isAdding = true;
      print('Adicionado aos favoritos: $contentId');
    }

    await saveFavorites(key, favorites);
    return isAdding;
  }

  /// Verifica se um item é favorito
  static Future<bool> isFavorite(String key, String contentId) async {
    final favorites = await loadFavorites(key);
    return favorites.contains(contentId);
  }

  /// Limpa todos os favoritos (útil para debug/reset)
  static Future<void> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(FAVORITE_MOVIES_KEY);
      await prefs.remove(FAVORITE_SERIES_KEY);
      await prefs.remove(FAVORITE_CHANNELS_KEY);
      await prefs.remove(MIGRATION_DONE_KEY);
      print('Todos os favoritos foram limpos');
    } catch (e) {
      print('Erro ao limpar favoritos: $e');
    }
  }
}