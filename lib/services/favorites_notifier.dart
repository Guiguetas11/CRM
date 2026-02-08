import 'package:flutter/foundation.dart';
import 'favorites_service.dart';

class FavoritesNotifier extends ChangeNotifier {
  Set<String> _movieFavorites = {};
  Set<String> _seriesFavorites = {};
  Set<String> _channelFavorites = {};

  Set<String> get movieFavorites => _movieFavorites;
  Set<String> get seriesFavorites => _seriesFavorites;
  Set<String> get channelFavorites => _channelFavorites;

  Future<void> loadAll() async {
    _movieFavorites = await FavoritesService.loadFavorites(FavoritesService.FAVORITE_MOVIES_KEY);
    _seriesFavorites = await FavoritesService.loadFavorites(FavoritesService.FAVORITE_SERIES_KEY);
    _channelFavorites = await FavoritesService.loadFavorites(FavoritesService.FAVORITE_CHANNELS_KEY);
    notifyListeners();
  }

  Future<void> toggleMovie(String title) async {
    final isAdding = await FavoritesService.toggleFavorite(
        FavoritesService.FAVORITE_MOVIES_KEY, title);
    if (isAdding) {
      _movieFavorites.add(title);
    } else {
      _movieFavorites.remove(title);
    }
    notifyListeners();
  }

  Future<void> toggleSeries(String title) async {
    final isAdding = await FavoritesService.toggleFavorite(
        FavoritesService.FAVORITE_SERIES_KEY, title);
    if (isAdding) {
      _seriesFavorites.add(title);
    } else {
      _seriesFavorites.remove(title);
    }
    notifyListeners();
  }

  Future<void> toggleChannel(String name) async {
    final isAdding = await FavoritesService.toggleFavorite(
        FavoritesService.FAVORITE_CHANNELS_KEY, name);
    if (isAdding) {
      _channelFavorites.add(name);
    } else {
      _channelFavorites.remove(name);
    }
    notifyListeners();
  }
}