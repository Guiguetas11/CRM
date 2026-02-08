import 'dart:convert';
import 'package:http/http.dart' as http;

class M3UContent {
  final String id;
  final String title;
  final String url;
  final String? logo;
  final String group;
  final String? description;
  final String? season;
  final String? episode;
  final String? seriesId;
  
  // Cache estático compartilhado entre todas as instâncias
  static final Map<String, String> _posterCache = {};
  
  static const String _tmdbApiKey = 'c896a7959ed6f26de5d0170fcb39fa06';
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/w500';

  M3UContent({
    required this.id,
    required this.title,
    required this.url,
    this.logo,
    required this.group,
    this.description,
    this.season,
    this.episode,
    this.seriesId,
  });

  /// Retorna a capa da série (busca via TMDB ou usa cache)
  static Future<String?> getSeriesPoster(String seriesTitle, {String? fallbackLogo}) async {
    // Extrai o nome limpo da série
    final cleanName = _extractSeriesName(seriesTitle);
    
    // Verifica cache primeiro
    if (_posterCache.containsKey(cleanName)) {
      return _posterCache[cleanName];
    }
    
    try {
      // Busca no TMDB
      final searchUrl = Uri.parse(
        'https://api.themoviedb.org/3/search/tv?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(cleanName)}&language=pt-BR'
      );
      
      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['results'] != null && data['results'].isNotEmpty) {
          final posterPath = data['results'][0]['poster_path'];
          
          if (posterPath != null) {
            final posterUrl = '$_tmdbImageBase$posterPath';
            _posterCache[cleanName] = posterUrl;
            return posterUrl;
          }
        }
      }
    } catch (e) {
      print('Erro ao buscar poster para "$cleanName": $e');
    }
    
    // Fallback para logo original ou placeholder
    return fallbackLogo;
  }

  /// Retorna a capa do filme (busca via TMDB ou usa cache)
  static Future<String?> getMoviePoster(String movieTitle, {String? fallbackLogo}) async {
    // Extrai o nome limpo do filme
    final cleanName = _extractSeriesName(movieTitle); // Usa a mesma lógica de limpeza
    
    // Verifica cache primeiro
    if (_posterCache.containsKey(cleanName)) {
      return _posterCache[cleanName];
    }
    
    try {
      // Busca no TMDB (endpoint diferente: search/movie)
      final searchUrl = Uri.parse(
        'https://api.themoviedb.org/3/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(cleanName)}&language=pt-BR'
      );
      
      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['results'] != null && data['results'].isNotEmpty) {
          final posterPath = data['results'][0]['poster_path'];
          
          if (posterPath != null) {
            final posterUrl = '$_tmdbImageBase$posterPath';
            _posterCache[cleanName] = posterUrl;
            return posterUrl;
          }
        }
      }
    } catch (e) {
      print('Erro ao buscar poster do filme "$cleanName": $e');
    }
    
    // Fallback para logo original ou placeholder
    return fallbackLogo;
  }

  /// Limpa o cache de posters (útil para forçar atualização)
  static void clearPosterCache() {
    _posterCache.clear();
  }

  /// Extrai o nome limpo da série do título
  /// Ex: "Breaking Bad S01E01 - Piloto" -> "Breaking Bad"
  static String _extractSeriesName(String title) {
    // Remove padrões comuns: S01E02, (2020), [720p], etc
    String clean = title
        .replaceAll(RegExp(r'S\d+E\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'T\d+E\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(\d{4}\)'), '')
        .replaceAll(RegExp(r'\[\d+p\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\s+-\s+.*'), '') // Remove "- Nome do episódio"
        .replaceAll(RegExp(r'\s+\d{4}\s*$'), '') // Remove ano no final
        .trim();
    
    return clean;
  }

  /// Verifica se o conteúdo casa com o texto de busca
  bool matchesSearch(String query) {
    final queryLower = query.toLowerCase();
    return title.toLowerCase().contains(queryLower) ||
        group.toLowerCase().contains(queryLower) ||
        (description?.toLowerCase().contains(queryLower) ?? false);
  }

  /// Extrai o número da temporada do título (ex: "S01E02" → 1)
  int? get seasonNumber {
    final match = RegExp(r'S(\d+)', caseSensitive: false).firstMatch(title);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Extrai o número do episódio do título (ex: "S01E02" → 2)
  int? get episodeNumber {
    final match = RegExp(r'E(\d+)', caseSensitive: false).firstMatch(title);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Constrói a partir de um JSON (útil para salvar em cache/localStorage)
  factory M3UContent.fromJson(Map<String, dynamic> json) {
    return M3UContent(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Sem título',
      url: json['url'] ?? '',
      logo: json['logo'],
      group: json['group'] ?? 'Outros',
      description: json['description'],
      season: json['season'],
      episode: json['episode'],
      seriesId: json['seriesId'],
    );
  }

  /// Converte para JSON (útil para salvar em cache/localStorage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'logo': logo,
      'group': group,
      'description': description,
      'season': season,
      'episode': episode,
      'seriesId': seriesId,
    };
  }

  /// Cria uma cópia do objeto com possíveis alterações
  M3UContent copyWith({
    String? id,
    String? title,
    String? url,
    String? logo,
    String? group,
    String? description,
    String? season,
    String? episode,
    String? seriesId,
  }) {
    return M3UContent(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      logo: logo ?? this.logo,
      group: group ?? this.group,
      description: description ?? this.description,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      seriesId: seriesId ?? this.seriesId,
    );
  }

  @override
  String toString() {
    return 'M3UContent{id: $id, title: $title, season: $season, episode: $episode}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is M3UContent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          url == other.url;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ url.hashCode;

  get hasExtraInfo => null;

  get extraInfo => null;
}