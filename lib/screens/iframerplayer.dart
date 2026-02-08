import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/sheets_services.dart';
import '../services/favorites_service.dart'; // NOVO: Importa o serviço centralizado
import 'channel_player_screen.dart';
import '../widgets/app_bottom_navigation.dart';

const String _imgViewTypeBase = 'channel-img-';
const Color _primaryColor = Color.fromARGB(255, 108, 9, 229);
const String _categoryAll = 'TODOS';

class IframePlayerRoute extends StatefulWidget {
  static const String id = '/iframeplayer';
  final bool isMobile; // ✅ ADICIONAR
  
  const IframePlayerRoute({
    super.key,
    this.isMobile = false, // ✅ ADICIONAR com valor padrão
  });

  @override
  State<IframePlayerRoute> createState() => _IframePlayerRouteState();
}

class _IframePlayerRouteState extends State<IframePlayerRoute> {
  String _searchQuery = '';
  String _selectedCategory = _categoryAll;

  final TextEditingController _searchController = TextEditingController();
  
  List<ChannelData> _allChannels = [];
  List<String> _categories = [_categoryAll];
  
  // ALTERAÇÃO: Usa Set<String> para favoritos
  Set<String> _favorites = {};
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // IMPORTANTE: Executa migração antes de carregar favoritos
    FavoritesService.migrateLegacyFavorites()
        .then((_) => _loadFavorites())
        .then((_) => _loadChannelsFromSheets());
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // ALTERAÇÃO: Usa FavoritesService para carregar favoritos
  Future<void> _loadFavorites() async {
    print('Carregando favoritos de canais...');
    final loadedFavorites = await FavoritesService.loadFavorites(
        FavoritesService.FAVORITE_CHANNELS_KEY);
    print('Favoritos carregados: ${loadedFavorites.length}');
    if (mounted) {
      setState(() {
        _favorites = loadedFavorites;
      });
    }
  }

  // ALTERAÇÃO: Usa FavoritesService para alternar favoritos
  Future<void> _toggleFavorite(String name) async {
    print('Toggle favorito canal: $name');
    final isAdding = await FavoritesService.toggleFavorite(
        FavoritesService.FAVORITE_CHANNELS_KEY, name);
    
    print('Favorito ${isAdding ? "adicionado" : "removido"}: $name');
    
    if (mounted) {
      setState(() {
        if (isAdding) {
          _favorites.add(name);
        } else {
          _favorites.remove(name);
        }
      });
    }
  }

  Future<void> _loadChannelsFromSheets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sheetsService = await SheetsServices.create();
      final channels = await sheetsService.getAllChannels();
      final categories = await sheetsService.getAllCategories();

      if (mounted) {
        setState(() {
          _allChannels = channels;
          _categories = [_categoryAll, ...categories];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar canais: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _openPlayer(ChannelData channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChannelPlayerScreen(
          channel: channel,
          isFavorite: _favorites.contains(channel.name),
          onToggleFavorite: () => _toggleFavorite(channel.name),
        ),
      ),
    ).then((_) {
      // Recarrega favoritos ao voltar
      _loadFavorites(); 
    });
  }

@override
Widget build(BuildContext context) {
  var filteredList = _allChannels.where((c) {
    final matchName = c.name.toLowerCase().contains(_searchQuery.toLowerCase());
    final matchCategory = _selectedCategory == _categoryAll || c.category == _selectedCategory;
    return matchName && matchCategory;
  }).toList();

  filteredList.sort((a, b) {
    final isFavA = _favorites.contains(a.name);
    final isFavB = _favorites.contains(b.name);

    if (isFavA && !isFavB) return -1;
    if (!isFavA && isFavB) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 36, 36, 36),
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      title: const Text(
        'VibesCines Tv',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primaryColor))
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
            : Column(
                children: [
                  _buildFilters(),
                  if (_selectedCategory != _categoryAll)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedCategory,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = _categoryAll;
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildGrid(filteredList)),
                ],
              ),
    bottomNavigationBar: AppBottomNavigation(
      currentIndex: 3,
      isMobile: widget.isMobile,
    ),
  );
}
Widget _buildFilters() {
  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar canais...',
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
              color: _selectedCategory != _categoryAll 
                  ?  Colors.lightGreen
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedCategory != _categoryAll 
                    ? Colors.lightGreen
                    : Colors.white24,
              ),
            ),
            child: Icon(
              Icons.filter_list,
              color: _selectedCategory != _categoryAll 
                  ? Colors.black 
                  : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showCategoryFilter() {
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
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: Colors.white,
                    ),
                    title: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
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

  Widget _buildGrid(List<ChannelData> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Nada encontrado", style: TextStyle(color: Colors.white)));
    }

    // 🚀 MUDANÇA PARA RESPONSIVIDADE
    // Usa SliverGridDelegateWithMaxCrossAxisExtent para adaptar o número de colunas
    // ao espaço disponível.
    const double maxItemWidth = 180.0; // Define o tamanho máximo de cada item (coluna)
    const double itemAspectRatio = 1.1;

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent( // <--- Alterado
        maxCrossAxisExtent: maxItemWidth, // <--- Novo parâmetro para responsividade
        childAspectRatio: itemAspectRatio, 
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        final isFav = _favorites.contains(c.name); // ALTERAÇÃO: Checa no Set

        return GestureDetector(
          onTap: () => _openPlayer(c),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              // Use a cor _primaryColor (roxo) ou mantenha a cor da borda existente (lightGreen)
              border: isFav ? Border.all(color: Colors.lightGreen, width: 2) : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(c.imageUrl, c), 
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          c.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        c.category,
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.lightGreen : Colors.grey.withOpacity(0.5),
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(c.name),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(String url, ChannelData channel) {
    if (url.isEmpty) {
      return Container(
        width: 60, 
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Icon(Icons.tv, color: Colors.white, size: 30),
      );
    }

    if (kIsWeb) {
      final uniqueId = '$_imgViewTypeBase${url.hashCode}';
      
      ui_web.platformViewRegistry.registerViewFactory(uniqueId, (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain' 
          ..style.borderRadius = '50%'
          ..style.backgroundColor = 'white'
          ..style.padding = '4px'
          ..style.boxSizing = 'border-box'
          ..style.cursor = 'pointer';
        
        img.onClick.listen((_) {
          _openPlayer(channel);
        });
        
        return img;
      });

      return SizedBox(
        width: 60,
        height: 60,
        child: HtmlElementView(viewType: uniqueId),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(4.0), 
          child: Image.network(
            url,
            fit: BoxFit.contain, 
            errorBuilder: (_, __, ___) =>
                Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.tv_off, color: Colors.white, size: 30)
                ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}