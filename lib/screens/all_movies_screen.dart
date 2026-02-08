import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibescines_app/services/favorites_notifier.dart';
import '../models/content_model.dart';
import '../services/content_service.dart';
import '../widgets/category_block.dart';
import 'category_screen.dart';
import 'video_player_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _movieColor = Color(0xFFFF5252);

class AllMoviesScreen extends StatefulWidget {
  final bool isMobile;
  const AllMoviesScreen({super.key, required this.isMobile});

  @override
  State<AllMoviesScreen> createState() => _AllMoviesScreenState();
}

class _AllMoviesScreenState extends State<AllMoviesScreen> {
  final ContentService _contentService = ContentService();
  final Map<String, List<M3UContent>> _originalContent = {};
  Map<String, List<M3UContent>> _filteredContent = {};
  List<M3UContent> _flatMovies = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;
  
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 0;
  final int _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentPage = 0;
      });
      _filterContent(_searchController.text);
    });
    
    // Carrega favoritos e conteúdo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesNotifier>().loadAll().then((_) {
        _loadContent();
      });
    });
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final categories = await _contentService.getMovieCategories();
      final sortedKeys = categories.keys.toList();
      sortedKeys.remove('4K');
      sortedKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final sortedCategories = <String, List<M3UContent>>{};
      if (categories.containsKey('4K')) {
        sortedCategories['4K'] = categories['4K'] ?? [];
      }
      for (final key in sortedKeys) {
        sortedCategories[key] = categories[key] ?? [];
      }

      setState(() {
        _originalContent.clear();
        _originalContent.addAll(sortedCategories);
      });
      
      _filterContent(_searchController.text);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar filmes: $e';
      });
    }
  }

  bool _shouldShowGrid() {
    if (_originalContent.isEmpty) return true;
    if (_originalContent.values.every((list) => list.isEmpty)) return true;

    if (_originalContent.length == 1) {
      final key = _originalContent.keys.first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if ((key.contains('sem') && key.contains('grupo')) || key == 'semgrupo') {
        return true;
      }
    }
    return false;
  }

  void _filterContent(String query) {
    final q = query.trim().toLowerCase();
    final favorites = context.read<FavoritesNotifier>().movieFavorites;

    if (_shouldShowGrid()) {
      final all = _originalContent.values.expand((e) => e).toList();
      var filtered = q.isEmpty 
          ? List<M3UContent>.from(all)
          : all.where((item) => item.title.toLowerCase().contains(q)).toList();
      
      if (_selectedCategory != null && _selectedCategory != 'Meus Favoritos') {
        filtered = filtered.where((item) => item.group == _selectedCategory).toList();
      } else if (_selectedCategory == 'Meus Favoritos') {
        filtered = filtered.where((item) => favorites.contains(item.title)).toList();
      }
      
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      setState(() {
        _flatMovies = filtered;
        _filteredContent.clear();
      });
      return;
    }

    final filtered = <String, List<M3UContent>>{};
    
    // Adiciona favoritos apenas se não houver busca ativa E (filtro de favoritos ativo OU nenhum filtro)
    if (q.isEmpty && (_selectedCategory == 'Meus Favoritos' || _selectedCategory == null)) {
      final favMovies = _originalContent.values
          .expand((e) => e)
          .where((item) => favorites.contains(item.title))
          .toList();
      
      if (favMovies.isNotEmpty) {
        favMovies.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        filtered['Meus Favoritos'] = favMovies;
      }
    }

    // Processa categorias normais
    if (_selectedCategory == null || _selectedCategory != 'Meus Favoritos') {
      for (final entry in _originalContent.entries) {
        // Se há categoria selecionada, ignora as outras
        if (_selectedCategory != null && entry.key != _selectedCategory) continue;
        
        // Filtra por título
        final matches = q.isEmpty
            ? List<M3UContent>.from(entry.value)
            : entry.value.where((item) => item.title.toLowerCase().contains(q)).toList();

        if (matches.isNotEmpty) {
          matches.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          filtered[entry.key] = matches;
        }
      }
    }
    
    // Se houver categoria selecionada (exceto Favoritos), mantém apenas ela
    if (_selectedCategory != null && _selectedCategory != 'Meus Favoritos') {
      final categoryContent = filtered.remove(_selectedCategory);
      filtered.clear();
      if (categoryContent != null) {
        filtered[_selectedCategory!] = categoryContent;
      }
    }

    setState(() {
      _filteredContent = filtered;
    });
  }

  List<String> _getAllCategories() {
    final categories = _originalContent.keys.toList();
    final favorites = context.read<FavoritesNotifier>().movieFavorites;
    final hasFavorites = favorites.isNotEmpty;
    if (hasFavorites) {
      categories.insert(0, 'Meus Favoritos');
    }
    return categories;
  }

  void _toggleFavorite(String movieTitle) async {
    await context.read<FavoritesNotifier>().toggleMovie(movieTitle);
    _filterContent(_searchQuery);
  }

  void _showCategoryFilter() {
    final categories = _getAllCategories();
    
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
                  'Filtrar por Categoria',
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
                  _selectedCategory == null ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.white,
                ),
                title: const Text(
                  'Todas as categorias',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                  _filterContent(_searchQuery);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    final isFavorites = category == 'Meus Favoritos';
                    
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isFavorites ? Colors.red : Colors.white,
                      ),
                      title: Text(
                        category,
                        style: TextStyle(
                          color: isFavorites ? Colors.red : Colors.white,
                          fontWeight: isFavorites ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isFavorites 
                          ? const Icon(Icons.favorite, color: Colors.red, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        _filterContent(_searchQuery);
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

  void _navigateToCategory(String category, List<M3UContent> contents) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          categoryName: category,
          contents: contents,
          isMobile: widget.isMobile,
        ),
      ),
    ).then((_) {
      _filterContent(_searchQuery);
    });
  }

  void _playContent(M3UContent content) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(content: content)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showGrid = _shouldShowGrid();

    return Consumer<FavoritesNotifier>(
      builder: (context, favoritesNotifier, child) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 36, 36, 36),
          appBar: AppBar(
            title: const Text(
              'VibeCines Filmes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
            ),
            centerTitle: true,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                                    hintText: 'Buscar filmes...',
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
                                onTap: _showCategoryFilter,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _selectedCategory != null 
                                        ? Colors.white 
                                        : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Icon(
                                    Icons.filter_list,
                                    color: _selectedCategory != null 
                                        ? Colors.black 
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedCategory != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedCategory == 'Meus Favoritos'
                                    ? Colors.red.withOpacity(0.2)
                                    : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedCategory == 'Meus Favoritos'
                                      ? Colors.red
                                      : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedCategory == 'Meus Favoritos'
                                        ? Icons.favorite
                                        : Icons.filter_alt,
                                    color: _selectedCategory == 'Meus Favoritos'
                                        ? Colors.red
                                        : Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _selectedCategory!,
                                      style: TextStyle(
                                        color: _selectedCategory == 'Meus Favoritos'
                                            ? Colors.white
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: _selectedCategory == 'Meus Favoritos'
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
                                        _selectedCategory = null;
                                      });
                                      _filterContent(_searchQuery);
                                    },
                                    child: Icon(
                                      Icons.close,
                                      color: _selectedCategory == 'Meus Favoritos'
                                          ? Colors.white
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
                          child: showGrid
                              ? _buildGridWithPagination()
                              : widget.isMobile
                                  ? _buildMobileLayout()
                                  : _buildDesktopLayout(),
                        ),
                      ],
                    ),
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 1,
            isMobile: widget.isMobile,
          ),
        );
      },
    );
  }

  Widget _buildGridWithPagination() {
    final favorites = context.watch<FavoritesNotifier>().movieFavorites;
    
    List<M3UContent> allMovies;
    if (_flatMovies.isNotEmpty || _searchQuery.isNotEmpty || _selectedCategory != null) {
      allMovies = List<M3UContent>.from(_flatMovies);
    } else {
      allMovies = _originalContent.values.expand((e) => e).toList();
    }

    if (allMovies.isEmpty) {
      return const Center(
        child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.white70)),
      );
    }

    allMovies.sort((a, b) {
      final favA = favorites.contains(a.title);
      final favB = favorites.contains(b.title);
      if (favA && !favB) return -1;
      if (!favA && favB) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    final totalItems = allMovies.length;
    final pageCount = (totalItems / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, totalItems);
    final pageItems = (start < end) ? allMovies.sublist(start, end) : <M3UContent>[];

    final crossAxisCount = widget.isMobile ? 2 : 5;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.64,
            ),
            itemCount: pageItems.length,
            itemBuilder: (_, index) {
              final movie = pageItems[index];
              final isFavorite = favorites.contains(movie.title);
              
              return GestureDetector(
                onTap: () => _playContent(movie),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: isFavorite 
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCover(movie, isFavorite),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _toggleFavorite(movie.title),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.white,
                              size: 18,
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
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  'Página ${_currentPage + 1} de $pageCount',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: _currentPage < pageCount - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_shouldShowGrid()) return _buildGridWithPagination();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_filteredContent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.white70)),
            ),
          )
        else
          ..._filteredContent.entries.map(
            (entry) => CategoryBlock(
              category: entry.key,
              contents: entry.value,
              onSeeAll: () => _navigateToCategory(entry.key, entry.value),
              onItemTap: _playContent,
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    if (_shouldShowGrid()) return _buildGridWithPagination();

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) {
              final category = _filteredContent.keys.elementAt(index);
              return CategoryBlock(
                category: category,
                contents: _filteredContent[category]!,
                onSeeAll: () =>
                    _navigateToCategory(category, _filteredContent[category]!),
                onItemTap: _playContent,
              );
            },
            childCount: _filteredContent.length,
          ),
        ),
      ],
    );
  }

  Widget _buildCover(M3UContent content, bool isFavorite) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: _MovieApiImage(
        key: ValueKey('movie_${content.id}_${content.title}_fav_$isFavorite'),
        movieTitle: content.title,
        fallbackLogo: content.logo,
      ),
    );
  }
}

class _MovieApiImage extends StatefulWidget {
  final String movieTitle;
  final String? fallbackLogo;

  const _MovieApiImage({
    Key? key,
    required this.movieTitle,
    this.fallbackLogo,
  }) : super(key: key);

  @override
  State<_MovieApiImage> createState() => _MovieApiImageState();
}

class _MovieApiImageState extends State<_MovieApiImage> {
  String? _posterUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  @override
  void didUpdateWidget(covariant _MovieApiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieTitle != widget.movieTitle) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _posterUrl = null;
    });

    try {
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
          _hasError = true;
        });
      }
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Icon(Icons.movie, color: Colors.white38, size: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: _movieColor,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_hasError || _posterUrl == null) {
      return _buildFallbackImage();
    }

    return Image.network(
      _posterUrl!,
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (_, __, ___) => _buildFallbackImage(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade900,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: _movieColor,
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}