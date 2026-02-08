// Arquivo: home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Serviços
import '../services/content_service.dart';
import '../services/sheets_services.dart';
import '../services/favorites_service.dart';
import '../services/favorites_notifier.dart';

// Importa as telas de navegação
import '../screens/all_movies_screen.dart'; 
import '../screens/all_series_screen.dart'; 
import '../screens/iframerplayer.dart';
import '../screens/video_player_screen.dart';
import '../screens/channel_player_screen.dart';
import '../screens/serie_screen.dart';

// Importa os modelos e widgets
import '../models/content_model.dart';
import '../widgets/channel_category_block.dart';

const Color _backgroundColor = Color(0xFF141414);
const Color _highlightColor = Color(0xFF00E5FF); 
const Color _primaryColor = Color.fromARGB(255, 108, 9, 229);

//CORES DAS BARRAS LATERAIS
const Color _tvLiveColor = Colors.green;           // Verde para TV ao Vivo
const Color _movieColor = Colors.red;              // Vermelho para Filmes
const Color _seriesColor = Color(0xFF00E5FF);      // Azul (highlightColor) para Séries

class HomeScreen extends StatefulWidget {
  static const String id = '/home';
  static const Color primaryColor = _primaryColor;

  final bool isMobile;
  final String userName;
  final String userEmail;

  const HomeScreen({
    super.key,
    required this.isMobile,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Serviços reais_loadSeries()
  final ContentService _contentService = ContentService();
  late SheetsServices _sheetsService;
  
  // Variáveis para armazenar o conteúdo da Home
  List<M3UContent> _homeMovies = [];
  List<M3UContent> _featuredMovies = [];
  List<M3UContent> _homeSeries = [];
  List<ChannelData> _homeChannels = [];
  List<M3UContent> _featuredSeries = [];
  
  // Nome do usuário
  String _displayName = '';
  bool _loadingName = true;

  bool _isLoading = true;
  String? _errorMessage;

    double _getScreenWidth(BuildContext context) {
       return MediaQuery.of(context).size.width;
      }

      Map<String, dynamic> _getResponsiveDimensions(BuildContext context) {
  final screenWidth = _getScreenWidth(context);
  final isDesktop = screenWidth > 800;
  
  // Calcula quantos cards cabem na tela no desktop
  int itemsPerRow = 6;
  if (screenWidth > 1400) {
    itemsPerRow = 8;
  } else if (screenWidth > 1200) {
    itemsPerRow = 7;
  } else if (screenWidth > 1000) {
    itemsPerRow = 6;
  } else if (screenWidth > 800) {
    itemsPerRow = 5;
  }
  
  return {
    'cardWidth': isDesktop ? 160.0 : 140.0,
    'cardHeight': isDesktop ? 240.0 : 220.0,
    'horizontalPadding': 16.0,
    'cardMargin': isDesktop ? 8.0 : 6.0,
    'titleSize': isDesktop ? 22.0 : 20.0,
    'itemsPerRow': itemsPerRow,
    'isDesktop': isDesktop,
  };
}

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _initAndFetch();
    // Executa migração e carrega favoritos no provider
    FavoritesService.migrateLegacyFavorites().then((_) {
      context.read<FavoritesNotifier>().loadAll();
      _loadHomeContent();
    });
  }

  Future<void> _initAndFetch() async {
    String email = widget.userEmail;
    if (email.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        email = prefs.getString('userEmail') ?? '';
      } catch (_) {
        email = '';
      }
    }

    if (email.trim().isNotEmpty) {
      try {
        final sheets = await SheetsServices.create();
        final name = await sheets.getNameByEmail(email.trim());
        if (name != null && name.isNotEmpty && mounted) {
          setState(() {
            _displayName = name;
          });
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _loadingName = false;
      });
    }
  }


  // Lógica de Ordenação (Favoritos primeiro)
void _sortContentByFavorites({bool sortChannels = true, bool sortMovies = true, bool sortSeries = true}) {
  final movieFavorites = context.read<FavoritesNotifier>().movieFavorites;
  final seriesFavorites = context.read<FavoritesNotifier>().seriesFavorites;
  final channelFavorites = context.read<FavoritesNotifier>().channelFavorites;

  // 1. Ordenar Canais (SOMENTE se sortChannels = true)
  if (sortChannels && _homeChannels.isNotEmpty) {
    _homeChannels.sort((a, b) {
      bool aFav = channelFavorites.contains(a.name);
      bool bFav = channelFavorites.contains(b.name);
      if (aFav && !bFav) return -1; 
      if (!aFav && bFav) return 1;  
      return 0;
    });
  }

  // 2. Ordenar Filmes (SOMENTE se sortMovies = true)
  if (sortMovies && _homeMovies.isNotEmpty) {
    _homeMovies.sort((a, b) {
      bool aFav = movieFavorites.contains(a.title);
      bool bFav = movieFavorites.contains(b.title);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });
  }

  // 3. Ordenar Séries (SOMENTE se sortSeries = true)
  if (sortSeries && _homeSeries.isNotEmpty) {
    _homeSeries.sort((a, b) {
      bool aFav = seriesFavorites.contains(a.title);
      bool bFav = seriesFavorites.contains(b.title);
      if (aFav && !bFav) return -1; 
      if (!aFav && bFav) return 1;
      return 0;
    });
  }
}
  // Função para carregar todo o conteúdo da Home
  Future<void> _loadHomeContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _sheetsService = await SheetsServices.create();

      await Future.wait(
        [
          _loadMovies(),
          _loadSeries(),
          _loadChannels(),
        ],
        eagerError: false,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Timeout ao carregar conteúdo');
          return [];
        },
      );

      _sortContentByFavorites();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar conteúdo da Home: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar conteúdo';
        });
      }
    }
  }

  // Helper para verificar ano (2025 ou maior) - EXCLUSIVO PARA TOP 10
  bool _is2025OrGreater(String title) {
    final regex = RegExp(r'\b(202[5-9]|20[3-9][0-9])\b');
    return regex.hasMatch(title);
  }

  // Helper para limpar o título (remover tags de qualidade/idioma) para comparação
  String _getBaseTitle(String title) {
    String cleaned = title.toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'\s?\[.*?\]\s?'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s?\(dublado\)\s?|\s?\(legendado\)\s?', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s?(4k|uhd|hd|fhd|720p|1080p)\s?', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s?\(\d{4}\)\s?'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s?[/-]\s?'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  // Carrega filmes
Future<void> _loadMovies() async {
  try {
    final movieCategories = await _contentService.getMovieCategories();
    final movieFavorites = context.read<FavoritesNotifier>().movieFavorites;
    
    // Lista de prioridades manuais
    final priorityNames = ['Venom', 'Deadpool', 'Superman (2025)', 'A Vingança de Popeye ', 'Ameaça no Ar', 'Batman: O Cavaleiro das Trevas', 'Tropa de Elite', 'Interestelar','Cidade de Deus', 'O Poderoso Chefão'];
    
    final List<M3UContent> featuredMovies = [];
    final Set<String> _baseTitlesAdded = {};

    // PASSO 1: Buscar PRIMEIRO os filmes da lista de prioridades (independente do ano)
    final List<M3UContent> allMoviesPool = [];
    for (var moviesList in movieCategories.values) {
      allMoviesPool.addAll(moviesList);
    }

    for (var priorityName in priorityNames) {
      if (featuredMovies.length >= 10) break;
      
      // Buscar filme que contenha o nome da prioridade
      final found = allMoviesPool.where((movie) => 
        movie.title.toLowerCase().contains(priorityName.toLowerCase()) && 
        !movie.title.contains('[L]')
      ).toList();
      
      if (found.isNotEmpty) {
        for (var movie in found) {
          if (featuredMovies.length >= 10) break;
          final baseTitle = _getBaseTitle(movie.title);
          if (!_baseTitlesAdded.contains(baseTitle)) {
            featuredMovies.add(movie);
            _baseTitlesAdded.add(baseTitle);
            break;
          }
        }
      }
    }

    // PASSO 2: Se ainda não tiver 10, completar com filmes 2025+ da categoria Lançamento
    if (featuredMovies.length < 10 && movieCategories.containsKey('Lançamento')) {
      final lancamentos = movieCategories['Lançamento']!;
      for (var movie in lancamentos) {
        if (featuredMovies.length >= 10) break;
        
        if (_is2025OrGreater(movie.title) && !movie.title.contains('[L]')) {
          final baseTitle = _getBaseTitle(movie.title);
          if (!_baseTitlesAdded.contains(baseTitle)) {
            featuredMovies.add(movie);
            _baseTitlesAdded.add(baseTitle);
          }
        }
      }
    }

    // PASSO 3: Se ainda não tiver 10, completar com outros filmes 2025+
    if (featuredMovies.length < 10) {
      for (var entry in movieCategories.entries) {
        if (entry.key != 'Lançamento') {
          for (var movie in entry.value) {
            if (featuredMovies.length >= 10) break;
            
            if (_is2025OrGreater(movie.title) && !movie.title.contains('[L]')) {
              final baseTitle = _getBaseTitle(movie.title);
              if (!_baseTitlesAdded.contains(baseTitle)) {
                featuredMovies.add(movie);
                _baseTitlesAdded.add(baseTitle);
              }
            }
          }
        }
        if (featuredMovies.length >= 10) break;
      }
    }

    // LISTA FILMES: Favoritos primeiro
    final favMovies = allMoviesPool.where((m) => movieFavorites.contains(m.title)).toList();
    final nonFavMovies = allMoviesPool.where((m) => !movieFavorites.contains(m.title)).toList();

    nonFavMovies.shuffle();
    final combinedMovies = [...favMovies, ...nonFavMovies];
    final List<M3UContent> horizontalMovies = combinedMovies.take(15).toList();

    if (mounted) {
      setState(() {
        _featuredMovies = featuredMovies;
        _homeMovies = horizontalMovies;
      });
    }
    
  } catch (e) {
    print('Erro ao carregar filmes: $e');
  }
}

  // Carrega séries (CORRIGIDO)
Future<void> _loadSeries() async {
  try {
    final seriesMap = await _contentService.getSeriesGroupedBySeason();
    final seriesFavorites = context.read<FavoritesNotifier>().seriesFavorites;
    
    // Lista de prioridades manuais
    final prioritySeriesNames = ['Stranger Things', 'Breaking Bad', 'Prison Break', 'Narcos', 'Reacher','Os Originais','A Rainha do Sul','ozark','La Casa de Papel','Round 6'];
    
    final List<M3UContent> featuredSeries = [];
    final Set<String> _seriesNamesAdded = {};

    //Buscar PRIMEIRO as séries da lista de prioridades (independente do ano)
    for (var priorityName in prioritySeriesNames) {
      if (featuredSeries.length >= 10) break;
      
      // Buscar série que contenha o nome da prioridade
      final matchingSeries = seriesMap.keys.firstWhere(
        (seriesName) => seriesName.toLowerCase().contains(priorityName.toLowerCase()),
        orElse: () => '',
      );
      
      if (matchingSeries.isNotEmpty && !_seriesNamesAdded.contains(matchingSeries)) {
        final seasons = seriesMap[matchingSeries]!;
        if (seasons.isNotEmpty) {
          final firstSeason = seasons.values.first;
          if (firstSeason.isNotEmpty) {
            final firstEpisode = firstSeason.first;
            final seriesRepresentative = M3UContent(
              id: firstEpisode.id,
              title: matchingSeries,
              url: firstEpisode.url,
              logo: firstEpisode.logo,
              group: firstEpisode.group,
            );
            featuredSeries.add(seriesRepresentative);
            _seriesNamesAdded.add(matchingSeries);
          }
        }
      }
    }

    // Se ainda não tiver 10, completar com séries 2025+
    if (featuredSeries.length < 10) {
      for (var seriesName in seriesMap.keys) {
        if (featuredSeries.length >= 10) break;
        
        if (_is2025OrGreater(seriesName) && !_seriesNamesAdded.contains(seriesName)) {
          final seasons = seriesMap[seriesName]!;
          if (seasons.isNotEmpty) {
            final firstSeason = seasons.values.first;
            if (firstSeason.isNotEmpty) {
              final firstEpisode = firstSeason.first;
              final seriesRepresentative = M3UContent(
                id: firstEpisode.id,
                title: seriesName,
                url: firstEpisode.url,
                logo: firstEpisode.logo,
                group: firstEpisode.group,
              );
              featuredSeries.add(seriesRepresentative);
              _seriesNamesAdded.add(seriesName);
            }
          }
        }
      }
    }

    //Se ainda não tiver 10, completar com outras séries
    if (featuredSeries.length < 10) {
      for (var seriesName in seriesMap.keys) {
        if (featuredSeries.length >= 10) break;
        
        if (!_seriesNamesAdded.contains(seriesName)) {
          final seasons = seriesMap[seriesName]!;
          if (seasons.isNotEmpty) {
            final firstSeason = seasons.values.first;
            if (firstSeason.isNotEmpty) {
              final firstEpisode = firstSeason.first;
              final seriesRepresentative = M3UContent(
                id: firstEpisode.id,
                title: seriesName,
                url: firstEpisode.url,
                logo: firstEpisode.logo,
                group: firstEpisode.group,
              );
              featuredSeries.add(seriesRepresentative);
              _seriesNamesAdded.add(seriesName);
            }
          }
        }
      }
    }

    // LISTA SÉRIES
    final List<M3UContent> allSeriesPool = [];

    for (var seriesName in seriesMap.keys) {
      final seasons = seriesMap[seriesName]!;
      if (seasons.isNotEmpty) {
        final firstSeason = seasons.values.first;
        if (firstSeason.isNotEmpty) {
          final firstEpisode = firstSeason.first;
          final seriesRepresentative = M3UContent(
            id: firstEpisode.id,
            title: seriesName,
            url: firstEpisode.url,
            logo: firstEpisode.logo,
            group: firstEpisode.group,
          );
          allSeriesPool.add(seriesRepresentative);
        }
      }
    }

    final favSeries = allSeriesPool.where((s) {
      return seriesFavorites.contains(s.title);
    }).toList();
    
    final nonFavSeries = allSeriesPool.where((s) {
      return !seriesFavorites.contains(s.title);
    }).toList();

    nonFavSeries.shuffle();
    final combinedSeries = [...favSeries, ...nonFavSeries];
    final List<M3UContent> homeSeriesList = combinedSeries.take(15).toList();

    if (mounted) {
      setState(() {
        _featuredSeries = featuredSeries;
        _homeSeries = homeSeriesList;
      });
    }

  } catch (e) {
    print('Erro ao carregar séries: $e');
  }
}

  // Carrega canais
Future<void> _loadChannels() async {
  try {
    final channels = await _sheetsService.getAllChannels();
    
    // ✅ NOVO: Ordena canais colocando favoritos no topo
    final channelFavorites = context.read<FavoritesNotifier>().channelFavorites;
    
    channels.sort((a, b) {
      bool aFav = channelFavorites.contains(a.name);
      bool bFav = channelFavorites.contains(b.name);
      if (aFav && !bFav) return -1; // Favorito A vem antes
      if (!aFav && bFav) return 1;  // Favorito B vem antes
      return 0; // Mantém ordem original se ambos forem ou não favoritos
    });
    
    if (mounted) {
      setState(() {
        _homeChannels = channels;
      });
    }
  } catch (e) {
    print('Erro ao carregar canais: $e');
  }
}
  
void _playContent(M3UContent content) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(content: content),
    ),
  ).then((_) {
    // ✅ ADICIONAR: Recarrega após voltar do player
    if (mounted) {
      context.read<FavoritesNotifier>().loadAll();
      _reorderContentOnly();
    }
  });
}

void _navigateToSeriesEpisodes(String seriesName) async {
  try {
    final seriesMap = await _contentService.getSeriesGroupedBySeason();
    
    if (seriesMap.containsKey(seriesName)) {
      final seasons = seriesMap[seriesName]!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SerieScreen(
            seriesName: seriesName,
            seasonsMap: seasons,
            isMobile: widget.isMobile,
          ),
        ),
      ).then((_) {
        // ✅ ADICIONAR: Recarrega após voltar da série
        if (mounted) {
          context.read<FavoritesNotifier>().loadAll();
          _reorderContentOnly();
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Série não encontrada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    print('Erro ao carregar episódios da série: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar episódios: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _navigateToChannel(ChannelData channel) {
  final channelFavorites = context.read<FavoritesNotifier>().channelFavorites;
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChannelPlayerScreen(
        channel: channel,
        isFavorite: channelFavorites.contains(channel.name),
        onToggleFavorite: () => context.read<FavoritesNotifier>().toggleChannel(channel.name),
      ),
    ),
  ).then((_) {
    // ✅ ADICIONAR: Recarrega e reordena após voltar do player
    if (mounted) {
      context.read<FavoritesNotifier>().loadAll();
      _sortContentByFavorites(sortChannels: true, sortMovies: false, sortSeries: false);
      setState(() {}); // Atualiza a UI
    }
  });
}
// Helper para construir card com título customizado (para TOP 10 de séries)
Widget _buildMovieCardCustomTitle(M3UContent content, bool isSeries, String displayTitle) {
  return Consumer<FavoritesNotifier>(
    builder: (context, favNotifier, child) {
      final movieFavorites = favNotifier.movieFavorites;
      final seriesFavorites = favNotifier.seriesFavorites;
      final isFav = isSeries 
          ? seriesFavorites.contains(content.title) 
          : movieFavorites.contains(content.title);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cartaz
            isSeries
                ? _SeriesApiImage(
                    seriesName: content.title,
                    fallbackLogo: content.logo,
                  )
                : _MovieApiImage(
                    movieTitle: content.title,
                    fallbackLogo: content.logo,
                  ),
            // Gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
            
            // Ícone de Favorito
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () async {
                  if (isSeries) {
                    await favNotifier.toggleSeries(content.title);
                    _sortContentByFavorites(sortChannels: false, sortMovies: false,sortSeries: true);
                  } else {
                    await favNotifier.toggleMovie(content.title);
                    _sortContentByFavorites(sortChannels: false, sortMovies: true,sortSeries: false);
                  }
                  // Reordena após toggle
                  setState(() {});
                },
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? (isSeries ? _seriesColor : _movieColor) : Colors.white70,
                  size: 24,
                ),
              ),
            ),

            // Título
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(blurRadius: 2, color: Colors.black, offset: Offset(0, 1))
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
} 
  
  // Construtor para listas horizontais (Filmes/Séries) com tamanho de 140x220
Widget _buildHorizontalListSection({
  required BuildContext context, 
  required String category, 
  required List<M3UContent> contents, 
  required VoidCallback onSeeAll,
  required bool isSeries,
  required Color barColor,
}) {
  if (contents.isEmpty) return const SizedBox.shrink();

  final dimensions = _getResponsiveDimensions(context);
  final isDesktop = dimensions['isDesktop'] as bool;

  // Lógica para determinar a função de TAP (Filme, Série ou Canal)
  void handleContentTap(M3UContent content) {
    if (category == 'TV AO VIVO') {
      _playContent(content);
    } else if (isSeries) {
      _navigateToSeriesEpisodes(content.title);
    } else {
      _playContent(content);
    }
  }

  // Lógica para determinar qual WIDGET DE CARD usar
  Widget cardBuilder(M3UContent content, bool isSeries, String displayTitle) {
     if (category == 'TV AO VIVO') {
       return _buildMovieCardCustomTitle(content, isSeries, displayTitle); 
     }
     return _buildMovieCardCustomTitle(content, isSeries, displayTitle);
  }
  
  const String seeAllText = 'Ver Tudo';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dimensions['horizontalPadding']!,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: dimensions['titleSize']!,
                  color: barColor,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: dimensions['titleSize']!,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                seeAllText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      
      if (isDesktop)
        _DesktopScrollableList(
          contents: contents, 
          dimensions: dimensions,
          isSeries: isSeries,
          cardBuilder: cardBuilder, 
          onTap: handleContentTap, 
        )
      else
        SizedBox(
          height: dimensions['cardHeight']!,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: dimensions['horizontalPadding']!,
            ),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              return Container(
                width: dimensions['cardWidth']!,
                margin: EdgeInsets.symmetric(
                  horizontal: dimensions['cardMargin']!,
                ),
                child: GestureDetector(
                  onTap: () => handleContentTap(content),
                  child: cardBuilder(content, isSeries, content.title),
                ),
              );
            },
          ),
        ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    final channelFavorites = context.watch<FavoritesNotifier>().channelFavorites;
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 36, 36, 36),
      appBar: AppBar(
        title: CustomAppBarContent(
          displayName: _displayName,
          userName: widget.userName,
          loadingName: _loadingName,
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      
body: _isLoading
    ? const Center(
        child: CircularProgressIndicator(color: _primaryColor)
      )
    : _errorMessage != null
        ? Center(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Seção TV AO VIVO
if (_homeChannels.isNotEmpty)
  ChannelCategoryBlockCircular(
    category: 'TV AO VIVO',
    channels: _homeChannels,
    onSeeAll: () {
      Navigator.pushNamed(context, IframePlayerRoute.id);
    },
    barColor: _tvLiveColor,
    onItemTap: _navigateToChannel,
    isFavorite: (name) => channelFavorites.contains(name),
    onToggleFavorite: (name) async {
      // ✅ Toggle o favorito
      await context.read<FavoritesNotifier>().toggleChannel(name);
      
      // ✅ Reordena INSTANTANEAMENTE
      if (mounted) {
        setState(() {
          _homeChannels.sort((a, b) {
            final updatedFavorites = context.read<FavoritesNotifier>().channelFavorites;
            bool aFav = updatedFavorites.contains(a.name);
            bool bFav = updatedFavorites.contains(b.name);
            if (aFav && !bFav) return -1;
            if (!aFav && bFav) return 1;
            return 0;
          });
        });
      }
    },
  ),            
                const SizedBox(height: 30),

                // 1. TOP 10 FILMES
                if (_featuredMovies.isNotEmpty)
                  _buildFeaturedListSection(context, _featuredMovies, false, barColor:  _movieColor, numberColor: _movieColor),

                const SizedBox(height: 30),

                // 2. FILMES 
                if (_homeMovies.isNotEmpty)
                  _buildHorizontalListSection(
                    context: context,
                    category: 'FILMES',
                    contents: _homeMovies,
                    isSeries: false,
                    barColor: _movieColor,
                    onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllMoviesScreen(isMobile: widget.isMobile),
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 30),

                // 3. TOP 10 SÉRIES
                if (_featuredSeries.isNotEmpty)
                  _buildFeaturedListSection(context, _featuredSeries, true , barColor: _seriesColor, numberColor: _seriesColor),
                

                const SizedBox(height: 30),

                // 4. SÉRIES
                if (_homeSeries.isNotEmpty)
                  _buildHorizontalListSection(
                    context: context,
                    category: 'SÉRIES',
                    contents: _homeSeries,
                    isSeries: true,
                    barColor:_seriesColor,
                    onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllSeriesScreen(isMobile: widget.isMobile),
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
      
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }
// LISTA HORIZONTAL TOP 10
Widget _buildFeaturedListSection(
  BuildContext context, 
  List<M3UContent> featuredContent, 
  bool isSeries,
  {required Color barColor, required Color numberColor}) {
  
  if (featuredContent.isEmpty) return const SizedBox.shrink();

  final dimensions = _getResponsiveDimensions(context);
  final isDesktop = dimensions['isDesktop'] as bool;
  final top10Items = featuredContent.take(10).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dimensions['horizontalPadding']!,
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: dimensions['titleSize']!,
              color: barColor, 
              margin: const EdgeInsets.only(right: 8),
            ),
            Text(
              isSeries ? 'TOP 10 SÉRIES' : 'TOP 10 FILMES',
              style: TextStyle(
                fontSize: dimensions['titleSize']!,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      
      // LÓGICA ATUALIZADA:
      // Desktop: Usa o componente de scroll com botões (sem quebrar linha)
      if (isDesktop)
        _DesktopScrollableList(
          contents: top10Items,
          dimensions: dimensions,
          isSeries: isSeries,
          onTap: (content) {
            if (isSeries) {
              _navigateToSeriesEpisodes(content.title); 
            } else {
              _playContent(content);
            }
          },
          // Customizamos o Card para incluir o número do Ranking (#1, #2...)
          cardBuilder: (content, isSeries, displayTitle) {
            // Descobre a posição (índice) para saber qual número exibir
            final index = top10Items.indexOf(content);
            final itemNumber = index + 1;

            return Stack(
              children: [
                _buildMovieCardCustomTitle(content, isSeries, displayTitle),
                Positioned(
                  top: 0,
                  right: 0, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: numberColor, 
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        topRight: Radius.circular(8), 
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(-2, 2),
                        )
                      ],
                    ),
                    child: Text(
                      '#$itemNumber',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        )
      
      // Mobile: Mantém a lista horizontal com scroll de toque (Arrastar)
      else
        SizedBox(
          height: dimensions['cardHeight']!,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: dimensions['horizontalPadding']!,
            ),
            itemCount: top10Items.length,
            itemBuilder: (context, index) {
              final content = top10Items[index];
              final itemNumber = index + 1;
              final displayTitle = content.title; 

              return Container(
                width: dimensions['cardWidth']!,
                margin: EdgeInsets.symmetric(
                  horizontal: dimensions['cardMargin']!,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (isSeries) {
                      _navigateToSeriesEpisodes(content.title); 
                    } else {
                      _playContent(content);
                    }
                  },
                  child: Stack(
                    children: [
                      _buildMovieCardCustomTitle(content, isSeries, displayTitle),
                      Positioned(
                        top: 0,
                        right: 0, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: numberColor, 
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              topRight: Radius.circular(8), 
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(-2, 2),
                              )
                            ],
                          ),
                          child: Text(
                            '#$itemNumber',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );
}


  Future<void> _logout() async {
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
              foregroundColor: _highlightColor,
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

        if (mounted) {
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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: _backgroundColor.withOpacity(0.95),
      unselectedItemColor: Colors.white54,
      selectedItemColor: _primaryColor, 
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 0: break;
case 1:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AllMoviesScreen(isMobile: widget.isMobile),
    ),
  ).then((_) {
    // ✅ CORRETO: Recarrega favoritos após voltar
    if (mounted) {
      context.read<FavoritesNotifier>().loadAll();
      _reorderContentOnly(); // Reordena o conteúdo
    }
  });
  break;
  
case 2:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AllSeriesScreen(isMobile: widget.isMobile),
    ),
  ).then((_) {
    // ✅ CORRETO: Recarrega favoritos após voltar
    if (mounted) {
      context.read<FavoritesNotifier>().loadAll();
      _reorderContentOnly(); // Reordena o conteúdo
    }
  });
  break;
  
case 3:
  Navigator.pushNamed(context, IframePlayerRoute.id).then((_) {
    // ✅ CORRETO: Recarrega favoritos após voltar
    if (mounted) {
      context.read<FavoritesNotifier>().loadAll();
    }
  });
  break;
          case 4:
            _logout();
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

  // ADICIONAR esta função NOVA (não substituir nada)
void _reorderContentOnly() {
  final movieFavorites = context.read<FavoritesNotifier>().movieFavorites;
  final seriesFavorites = context.read<FavoritesNotifier>().seriesFavorites;
  final channelFavorites = context.read<FavoritesNotifier>().channelFavorites;

  // ✅ ADICIONAR: Reordena canais
  if (_homeChannels.isNotEmpty) {
    _homeChannels.sort((a, b) {
      bool aFav = channelFavorites.contains(a.name);
      bool bFav = channelFavorites.contains(b.name);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });
    setState(() {});
  }

  // Reordena filmes
  if (_homeMovies.isNotEmpty) {
    _homeMovies.sort((a, b) {
      bool aFav = movieFavorites.contains(a.title);
      bool bFav = movieFavorites.contains(b.title);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });
  }

  // Reordena séries
  if (_homeSeries.isNotEmpty) {
    _homeSeries.sort((a, b) {
      bool aFav = seriesFavorites.contains(a.title);
      bool bFav = seriesFavorites.contains(b.title);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    }); 
  }

  setState(() {}); // Atualiza UI
}





}



// --- NOVO WIDGET PARA DESKTOP COM BOTÕES DE SCROLL ---
class _DesktopScrollableList extends StatefulWidget {
  final List<M3UContent> contents;
  final Map<String, dynamic> dimensions;
  final Function(M3UContent) onTap;
  final bool isSeries;
  final Widget Function(M3UContent, bool, String) cardBuilder;

  const _DesktopScrollableList({
    required this.contents,
    required this.dimensions,
    required this.onTap,
    required this.isSeries,
    required this.cardBuilder,
  });

  @override
  State<_DesktopScrollableList> createState() => _DesktopScrollableListState();
}

class _DesktopScrollableListState extends State<_DesktopScrollableList> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftButton = false;
  bool _showRightButton = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateButtonVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateButtonVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateButtonVisibility() {
    setState(() {
      _showLeftButton = _scrollController.offset > 0;
      _showRightButton = _scrollController.offset < _scrollController.position.maxScrollExtent;
    });
  }

  void _scroll(double offset) {
    final target = _scrollController.offset + offset;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.dimensions['cardWidth'] as double;
    final cardHeight = widget.dimensions['cardHeight'] as double;
    final cardMargin = widget.dimensions['cardMargin'] as double;
    
    // Calcula quanto rolar (aproximadamente 4 cards por clique)
    final scrollAmount = (cardWidth + (cardMargin * 2)) * 4;

    return Stack(
      children: [
        // A Lista Horizontal
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: widget.dimensions['horizontalPadding']!,
            ),
            itemCount: widget.contents.length,
            itemBuilder: (context, index) {
              final content = widget.contents[index];
              return Container(
                width: cardWidth,
                margin: EdgeInsets.symmetric(horizontal: cardMargin),
                child: GestureDetector(
                  onTap: () => widget.onTap(content),
                  child: widget.cardBuilder(content, widget.isSeries, content.title),
                ),
              );
            },
          ),
        ),

        // Botão Esquerdo
        if (_showLeftButton)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildScrollButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => _scroll(-scrollAmount),
              ),
            ),
          ),

        // Botão Direito
        if (_showRightButton)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildScrollButton(
                icon: Icons.arrow_forward_ios,
                onTap: () => _scroll(scrollAmount),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScrollButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7), // Fundo preto semitransparente
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _SeriesApiImage extends StatefulWidget {
  final String seriesName;
  final String? fallbackLogo;

  const _SeriesApiImage({
    required this.seriesName,
    this.fallbackLogo,
  });

  @override
  State<_SeriesApiImage> createState() => _SeriesApiImageState();
}

class _SeriesApiImageState extends State<_SeriesApiImage> {
  String? _posterUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  // 🌟 SOLUÇÃO: Garante que o poster é recarregado se o widget for reutilizado com outra série
  @override
  void didUpdateWidget(covariant _SeriesApiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesName != widget.seriesName) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    // Reset o estado
    if (mounted) {
      setState(() {
        _isLoading = true;
        _posterUrl = null;
      });
    }

    // Chama a lógica de busca da capa via API (M3UContent.getSeriesPoster)

    final posterUrl = await M3UContent.getSeriesPoster( 
      widget.seriesName,
      fallbackLogo: widget.fallbackLogo,
    );

    if (mounted) {
      setState(() {
        _posterUrl = posterUrl;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.shade900,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              // Usando _seriesColor, assumindo que está definido no escopo de home_screen.dart
              color: _seriesColor, 
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final displayUrl = _posterUrl ?? widget.fallbackLogo;

    if (displayUrl == null) {
      return Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.live_tv, color: Colors.white38, size: 30),
      );
    }

    // Usa BoxFit.cover para preencher o cartão, como o Image.network original
    return Image.network(
      displayUrl,
      fit: BoxFit.cover, 
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.tv_off, color: Colors.white38),
      ),
    );
  }
}
  //CHAMADA PARA API 
class _MovieApiImage extends StatefulWidget {
  final String movieTitle;
  final String? fallbackLogo;

  const _MovieApiImage({
    required this.movieTitle,
    this.fallbackLogo,
  });

  @override
  State<_MovieApiImage> createState() => _MovieApiImageState();
}

class _MovieApiImageState extends State<_MovieApiImage> {
  String? _posterUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  // Garante que o poster é recarregado se o widget for reutilizado com outro filme
  @override
  void didUpdateWidget(covariant _MovieApiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieTitle != widget.movieTitle) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    // Reset o estado
    if (mounted) {
      setState(() {
        _isLoading = true;
        _posterUrl = null;
      });
    }

    try {
      // Chamada para a lógica de busca da capa via API para filmes
      final posterUrl = await M3UContent.getMoviePoster( 
        widget.movieTitle,
        fallbackLogo: widget.fallbackLogo,
      );

      if (mounted) {
        setState(() {
          _posterUrl = posterUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget para exibir a imagem de fallback em caso de erro ou URL nulo
  Widget _buildFallbackContainer() {
    return Container(
      color: Colors.grey[800],
      alignment: Alignment.center,
      child: const Icon(Icons.movie, color: Colors.white38, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.shade900,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              // Usando _movieColor (Vermelho) para filmes
              color: _movieColor, 
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final displayUrl = _posterUrl ?? widget.fallbackLogo;

    if (displayUrl == null) {
      return _buildFallbackContainer();
    }

    // Usa BoxFit.cover para preencher o cartão
    return Image.network(
      displayUrl,
      fit: BoxFit.cover, 
      errorBuilder: (_, __, ___) => _buildFallbackContainer(),
    );
  }
}


class CustomAppBarContent extends StatefulWidget {
  final String displayName;
  final String userName;
  final bool loadingName;

  const CustomAppBarContent({
    super.key,
    required this.displayName,
    required this.userName,
    required this.loadingName,
  });

  @override
  State<CustomAppBarContent> createState() => _CustomAppBarContentState();
}

class _CustomAppBarContentState extends State<CustomAppBarContent> {
  late Timer _timer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Atualiza o horário a cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    // Fuso horário de Brasília (UTC-3)
    final brasiliaTime = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final formatter = DateFormat('HH:mm');
    if (mounted) {
      setState(() {
        _currentTime = formatter.format(brasiliaTime);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determina se é Desktop baseado na largura da tela (mesma lógica usada no HomeScreen)
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    // Nome a ser exibido
    final nameToDisplay = widget.loadingName
        ? '...'
        : (widget.displayName.isNotEmpty ? widget.displayName : widget.userName);

    // LÓGICA DA APPBAR DINÂMICA
    
    // DESKTOP: Logo e Hora
    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo (Nome do App)
          const Text(
            'VibeCines',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 24, // Fonte um pouco maior para Desktop
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          
          // Horário
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: Colors.black26,
               borderRadius: BorderRadius.circular(8),
             ),
             child: Text(
              _currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      );
    } 
    
    // MOBILE: AppBar Compacta
    else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Esquerda: Nome do app
          const Text(
            'VibeCines',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          
          // Direita: Chip com nome do usuário e horário juntos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), // Fundo translúcido
              borderRadius: BorderRadius.circular(20), // Borda arredondada (Chip)
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone de usuário
                const Icon(Icons.person, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                
                // Nome do usuário (com limite de tamanho para não quebrar layout)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    nameToDisplay.split(' ')[0], // Pega apenas o primeiro nome para economizar espaço
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Separador
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('•', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                
                // Horário
                Text(
                  _currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}