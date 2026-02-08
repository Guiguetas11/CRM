import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content_model.dart';
import '../screens/video_player_screen.dart';
import '../widgets/movie_api_image.dart';
import '../services/favorites_notifier.dart';

const Color _highlightColor = Color(0xFF9223FF);
const Color _seriesColor = Color(0xFF00E5FF);
const Color _movieColor = Color(0xFFFF5252);

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  final List<M3UContent> contents;
  final bool isMobile;
  final bool isSeries;
  final Function(M3UContent)? onSeriesTap;

  const CategoryScreen({
    required this.categoryName,
    required this.contents,
    required this.isMobile,
    this.isSeries = false,
    this.onSeriesTap,
    super.key,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String query = "";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  final int _itemsPerPage = 24;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _playContent(M3UContent content) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(content: content)),
    );
  }

  void _changePage(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _getColumnsCount(double screenWidth, bool isMobile) {
    if (isMobile) {
      return 3;
    } else if (screenWidth < 600) {
      return 3;
    } else if (screenWidth < 900) {
      return 4;
    } else if (screenWidth < 1200) {
      return 5;
    } else if (screenWidth < 1600) {
      return 6;
    } else {
      return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, favNotifier, child) {
        final filtered = widget.contents.where((c) {
          return c.title.toLowerCase().contains(query.toLowerCase());
        }).toList();

        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        final totalItems = filtered.length;
        final totalPages = (totalItems / _itemsPerPage).ceil();
        
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        final startIndex = _currentPage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage < totalItems) 
            ? startIndex + _itemsPerPage 
            : totalItems;
            
        final currentItems = (startIndex < totalItems) 
            ? filtered.sublist(startIndex, endIndex) 
            : <M3UContent>[];

        final screenWidth = MediaQuery.of(context).size.width;
        final columns = _getColumnsCount(screenWidth, widget.isMobile);
        const horizontalPadding = 16.0;
        const itemSpacing = 10.0;
        final totalSpacing = itemSpacing * (columns - 1);
        final totalPadding = horizontalPadding * 2;
        final itemWidth = (screenWidth - totalPadding - totalSpacing) / columns;
        final itemHeight = itemWidth * 1.5;

        final favorites = widget.isSeries 
            ? favNotifier.seriesFavorites 
            : favNotifier.movieFavorites;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              widget.categoryName,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar em ${widget.categoryName}...',
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
              
              Expanded(
                child: filtered.isEmpty && query.isNotEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum resultado encontrado.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : currentItems.isEmpty 
                      ? const Center(child: Text('Nenhum item nesta categoria.', style: TextStyle(color: Colors.white54)))
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: itemSpacing,
                            mainAxisSpacing: itemSpacing,
                            childAspectRatio: itemWidth / itemHeight,
                          ),
                          itemCount: currentItems.length,
                          itemBuilder: (context, index) {
                            final content = currentItems[index];
                            final isFav = favorites.contains(content.title);
                            
                            Widget cardWidget;

                            if (widget.isSeries) {
                              cardWidget = _SeriesCoverCard(
                                content: content,
                                width: itemWidth.toDouble(),
                                isFavorite: isFav,
                                onToggleFavorite: () => favNotifier.toggleSeries(content.title),
                              );
                            } else {
                              cardWidget = _MovieCoverCard(
                                content: content,
                                width: itemWidth.toDouble(),
                                isFavorite: isFav,
                                onToggleFavorite: () => favNotifier.toggleMovie(content.title),
                              );
                            }

                            return GestureDetector(
                              onTap: () {
                                if (widget.isSeries) {
                                  widget.onSeriesTap?.call(content);
                                } else {
                                  _playContent(content);
                                }
                              },
                              child: cardWidget,
                            );
                          },
                        ),
              ),

              if (totalPages > 1)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0 
                            ? () => _changePage(_currentPage - 1) 
                            : null,
                        icon: Icon(
                          Icons.arrow_back_ios_rounded, 
                          color: _currentPage > 0 ? Colors.white : Colors.white24,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Text(
                        'Página ${_currentPage + 1} de $totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      IconButton(
                        onPressed: _currentPage < totalPages - 1 
                            ? () => _changePage(_currentPage + 1) 
                            : null,
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded, 
                          color: _currentPage < totalPages - 1 ? Colors.white : Colors.white24,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MovieCoverCard extends StatelessWidget {
  final M3UContent content;
  final double width;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _MovieCoverCard({
    required this.content,
    required this.width,
    required this.isFavorite,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = width * 1.5;

    return SizedBox(
      width: width,
      height: cardHeight,
      child: ClipRRect( 
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MovieApiImage(
              movieTitle: content.title,
              fallbackLogo: content.logo,
              fit: BoxFit.cover,
            ),

            if (onToggleFavorite != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onToggleFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? _movieColor : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  content.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesCoverCard extends StatefulWidget {
  final M3UContent content;
  final double width;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _SeriesCoverCard({
    required this.content,
    required this.width,
    required this.isFavorite,
    this.onToggleFavorite,
    Key? key,
  }) : super(key: key);

  @override
  State<_SeriesCoverCard> createState() => _SeriesCoverCardState();
}

class _SeriesCoverCardState extends State<_SeriesCoverCard> {
  String? _posterUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }
  
  @override
  void didUpdateWidget(covariant _SeriesCoverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.title != widget.content.title) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _posterUrl = null;
      });
    }

    try {
      final posterUrl = await M3UContent.getSeriesPoster(
        widget.content.title,
        fallbackLogo: widget.content.logo,
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
      child: const Icon(Icons.tv_off, color: Colors.white38, size: 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = widget.width * 1.5;

    return SizedBox(
      width: widget.width,
      height: cardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _isLoading
                ? Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: _seriesColor,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : (_posterUrl != null && !_hasError)
                    ? Image.network(
                        _posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackImage(),
                      )
                    : _buildFallbackImage(),
            
            if (widget.onToggleFavorite != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onToggleFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.isFavorite ? _seriesColor : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  widget.content.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}