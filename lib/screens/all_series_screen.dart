import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content_model.dart';
import '../services/content_service.dart';
import '../screens/serie_screen.dart';
import '../services/favorites_service.dart';
import '../services/favorites_notifier.dart';
import 'category_screen.dart';
import '../widgets/app_bottom_navigation.dart';

const Color _highlightColor = Color(0xFF00E5FF);

class AllSeriesScreen extends StatefulWidget {
  final bool isMobile;

  const AllSeriesScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<AllSeriesScreen> createState() => _AllSeriesScreenState();
}

class _AllSeriesScreenState extends State<AllSeriesScreen>
    with AutomaticKeepAliveClientMixin {
  final ContentService _contentService = ContentService();
  final Map<String, Map<String, List<M3UContent>>> _seriesMap = {};
  final Map<String, List<SeriesInfo>> _seriesByGroup = {};
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedGroup;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _organizeSeriesByGroup();
      });
    });
  }

  Future<void> _initializeData() async {
    await FavoritesService.migrateLegacyFavorites();
    
    // Carrega os favoritos no notifier
    if (mounted) {
      await context.read<FavoritesNotifier>().loadAll();
    }
    
    await _loadSeries();
  }

  Future<void> _loadSeries() async {
    try {
      final seriesMap = await _contentService.getSeriesGroupedBySeason();
      setState(() {
        _seriesMap.addAll(seriesMap);
        _organizeSeriesByGroup();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar séries: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _organizeSeriesByGroup() {
    final favorites = context.read<FavoritesNotifier>().seriesFavorites;
    final Map<String, List<SeriesInfo>> organized = {};
    
    for (final entry in _seriesMap.entries) {
      final seriesName = entry.key;
      final seasonsMap = entry.value;
      
      // Verifica se a série corresponde à busca
      if (_searchQuery.isNotEmpty && 
          !seriesName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }
      
      // Pega o primeiro episódio para obter o grupo e logo
      final firstEpisode = seasonsMap.values.expand((e) => e).first;
      final group = firstEpisode.group ?? 'Sem Grupo';
      
      // Se há filtro de grupo selecionado, filtra
      if (_selectedGroup != null && _selectedGroup != 'Meus Favoritos' && group != _selectedGroup) {
        continue;
      }
      
      if (!organized.containsKey(group)) {
        organized[group] = [];
      }
      
      organized[group]!.add(SeriesInfo(
        name: seriesName,
        seasonsMap: seasonsMap,
        logo: firstEpisode.logo,
      ));
    }
    
    // Adiciona categoria de favoritos
    if (favorites.isNotEmpty && (_selectedGroup == null || _selectedGroup == 'Meus Favoritos')) {
      final favSeries = <SeriesInfo>[];
      
      for (final entry in _seriesMap.entries) {
        final seriesName = entry.key;
        
        if (!favorites.contains(seriesName)) continue;
        
        // Verifica se a série corresponde à busca
        if (_searchQuery.isNotEmpty && 
            !seriesName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        
        final seasonsMap = entry.value;
        final firstEpisode = seasonsMap.values.expand((e) => e).first;
        
        favSeries.add(SeriesInfo(
          name: seriesName,
          seasonsMap: seasonsMap,
          logo: firstEpisode.logo,
        ));
      }
      
      if (favSeries.isNotEmpty) {
        favSeries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        organized['Meus Favoritos'] = favSeries;
      }
    }
    
    // Ordena as séries dentro de cada grupo
    for (final group in organized.keys) {
      organized[group]!.sort((a, b) {
        final favA = favorites.contains(a.name);
        final favB = favorites.contains(b.name);
        if (favA && !favB) return -1;
        if (!favA && favB) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    
    setState(() {
      _seriesByGroup.clear();
      
      // Coloca "Meus Favoritos" primeiro, depois ordena o resto
      if (organized.containsKey('Meus Favoritos')) {
        _seriesByGroup['Meus Favoritos'] = organized['Meus Favoritos']!;
        organized.remove('Meus Favoritos');
      }
      
      final sortedGroups = organized.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
      for (final group in sortedGroups) {
        _seriesByGroup[group] = organized[group]!;
      }
    });
  }

  List<String> _getAllGroups() {
    final favorites = context.read<FavoritesNotifier>().seriesFavorites;
    final allGroups = <String>{};
    
    for (final seasonsMap in _seriesMap.values) {
      for (final episodes in seasonsMap.values) {
        for (final episode in episodes) {
          if (episode.group != null && episode.group!.isNotEmpty) {
            allGroups.add(episode.group!);
          }
        }
      }
    }
    
    final sortedGroups = allGroups.toList();
    sortedGroups.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    
    if (favorites.isNotEmpty) {
      sortedGroups.insert(0, 'Meus Favoritos');
    }
    
    return sortedGroups;
  }

  void _toggleFavorite(String seriesName) async {
    await context.read<FavoritesNotifier>().toggleSeries(seriesName);
    if (mounted) {
    setState(() {
      _organizeSeriesByGroup();
    });
  }
  }

  void _showGroupFilter() {
    final allGroups = _getAllGroups();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'Filtrar por Grupo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Icon(
                  _selectedGroup == null ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.white,
                ),
                title: const Text(
                  'Todos os grupos',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _selectedGroup = null;
                    _organizeSeriesByGroup();
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allGroups.length,
                  itemBuilder: (context, index) {
                    final group = allGroups[index];
                    final isSelected = _selectedGroup == group;
                    final isFavorites = group == 'Meus Favoritos';
                    
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isFavorites ? _highlightColor : Colors.white,
                      ),
                      title: Text(
                        group,
                        style: TextStyle(
                          color: isFavorites ? _highlightColor : Colors.white,
                          fontWeight: isFavorites ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isFavorites 
                          ? const Icon(Icons.favorite, color: _highlightColor, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedGroup = group;
                          _organizeSeriesByGroup();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSerie(SeriesInfo series) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SerieScreen(
          seriesName: series.name,
          seasonsMap: series.seasonsMap,
          isMobile: widget.isMobile,
        ),
      ),
    ).then((_) {
      // Recarrega a organização após voltar da tela de série
      _organizeSeriesByGroup();
    });
  }

  void _navigateToCategory(String category, List<SeriesInfo> series) {
    // Converte SeriesInfo para M3UContent para usar na CategoryScreen
    final contents = series.map((s) {
      final firstEpisode = s.seasonsMap.values.expand((e) => e).first;
      return M3UContent(
        id: firstEpisode.id,
        title: s.name,
        url: firstEpisode.url,
        logo: s.logo,
        group: category,
      );
    }).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          categoryName: category,
          contents: contents,
          isMobile: widget.isMobile,
          isSeries: true,
          onSeriesTap: (content) {
            final seriesInfo = series.firstWhere((s) => s.name == content.title);
            _navigateToSerie(seriesInfo);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<FavoritesNotifier>(
      builder: (context, favoritesNotifier, child) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 36, 36, 36),
          appBar: AppBar(
            title: const Text(
              'VibeCines Séries',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
            ),
            centerTitle: true,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _highlightColor))
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar séries...',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                    filled: true,
                                    fillColor: const Color(0xFF1E1E1E),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showGroupFilter,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _selectedGroup != null 
                                        ? _highlightColor 
                                        : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedGroup != null 
                                          ? _highlightColor 
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.filter_list,
                                    color: _selectedGroup != null 
                                        ? Colors.black 
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedGroup != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedGroup == 'Meus Favoritos'
                                    ? _highlightColor.withOpacity(0.2)
                                    : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedGroup == 'Meus Favoritos'
                                      ? _highlightColor
                                      : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedGroup == 'Meus Favoritos'
                                        ? Icons.favorite
                                        : Icons.filter_alt,
                                    color: _selectedGroup == 'Meus Favoritos'
                                        ? _highlightColor
                                        : Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _selectedGroup!,
                                      style: TextStyle(
                                        color: _selectedGroup == 'Meus Favoritos'
                                            ? _highlightColor
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: _selectedGroup == 'Meus Favoritos'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedGroup = null;
                                        _organizeSeriesByGroup();
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      color: _selectedGroup == 'Meus Favoritos'
                                          ? _highlightColor
                                          : Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _seriesByGroup.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma série encontrada',
                                      style: TextStyle(color: Colors.white70)),
                                )
                              : widget.isMobile
                                  ? _buildMobileLayout(favoritesNotifier.seriesFavorites)
                                  : _buildDesktopLayout(favoritesNotifier.seriesFavorites),
                        ),
                      ],
                    ),
              bottomNavigationBar: AppBottomNavigation(
              currentIndex: 2, // 2 = Séries
              isMobile: widget.isMobile,
               ),);
      },
    );
  }

  Widget _buildMobileLayout(Set<String> favorites) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: _seriesByGroup.entries.map(
        (entry) => _buildSeriesBlock(entry.key, entry.value, favorites),
      ).toList(),
    );
  }

  Widget _buildDesktopLayout(Set<String> favorites) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) {
              final entry = _seriesByGroup.entries.elementAt(index);
              return _buildSeriesBlock(entry.key, entry.value, favorites);
            },
            childCount: _seriesByGroup.length,
          ),
        ),
      ],
    );
  }

  Widget _buildSeriesBlock(String group, List<SeriesInfo> series, Set<String> favorites) {
    final isFavorites = group == 'Meus Favoritos';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _highlightColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                if (isFavorites)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.favorite,
                      color: _highlightColor,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isFavorites ? _highlightColor : Colors.white,
                    ),
                  ),
                ),
                if (series.length > 6)
                  GestureDetector(
                    onTap: () => _navigateToCategory(group, series),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                     colors: [_highlightColor, Color.fromARGB(255, 0, 195, 255)],
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver Tudo',
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: series.length,
              itemBuilder: (_, index) {
                final seriesInfo = series[index];
                final isFav = favorites.contains(seriesInfo.name);
                
                return GestureDetector(
                  key: ValueKey('${seriesInfo.name}_${isFav}_$group'),
                  onTap: () => _navigateToSerie(seriesInfo),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: isFav ? Border.all(color: _highlightColor, width: 2) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _SeriesPosterImage(
                            key: ValueKey('poster_${seriesInfo.name}_${isFav}_$group'),
                            seriesName: seriesInfo.name,
                            fallbackLogo: seriesInfo.logo,
                          ),
                        ),
 
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
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
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _toggleFavorite(seriesInfo.name),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? _highlightColor : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Text(
                            seriesInfo.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  blurRadius: 2,
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                )
                              ],
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
      ),
    );
  }
}

/// Widget personalizado para carregar a capa da série via TMDB
class _SeriesPosterImage extends StatefulWidget {
  final String seriesName;
  final String? fallbackLogo;

  const _SeriesPosterImage({
    super.key,
    required this.seriesName,
    this.fallbackLogo,
  });

  @override
  State<_SeriesPosterImage> createState() => _SeriesPosterImageState();
}

class _SeriesPosterImageState extends State<_SeriesPosterImage> {
  String? _posterUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  Future<void> _loadPoster() async {
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: _highlightColor,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_hasError || _posterUrl == null) {
      return Container(
        color: Colors.grey[800],
        child: const Icon(Icons.tv, color: Colors.white38, size: 48),
      );
    }

    return Image.network(
      _posterUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[900],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: _highlightColor,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.tv, color: Colors.white38, size: 48),
      ),
    );
  }
}

class SeriesInfo {
  final String name;
  final Map<String, List<M3UContent>> seasonsMap;
  final String? logo;

  SeriesInfo({
    required this.name,
    required this.seasonsMap,
    this.logo,
  });
}