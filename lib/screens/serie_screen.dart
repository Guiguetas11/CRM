import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart'; // 1. Import do Provider

// IMPORTA O SERVIÇO DE FAVORITOS (Ajuste o caminho se necessário)
import '../services/favorites_notifier.dart'; // 2. Import do Notifier

import 'ts_mobile_player.dart';

const Color _highlightColor = Color(0xFF00E5FF);

class SerieScreen extends StatefulWidget {
  final String seriesName;
  final Map<String, List<M3UContent>> seasonsMap;
  final bool isMobile;

  const SerieScreen({
    super.key,
    required this.seriesName,
    required this.seasonsMap,
    required this.isMobile,
  });

  @override
  State<SerieScreen> createState() => _SerieScreenState();
}

class _SerieScreenState extends State<SerieScreen> {
  Set<String> watchedEpisodes = {};
  String? selectedSeason;
  String? seriesLogo;

  @override
  void initState() {
    super.initState();
    _loadWatchedEpisodes();

    final sortedSeasons = widget.seasonsMap.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.compareTo(b);
      });

    selectedSeason = sortedSeasons.isNotEmpty ? sortedSeasons.first : null;

    final firstEpisode = widget.seasonsMap.values.expand((e) => e).firstOrNull;
    seriesLogo = firstEpisode?.logo;
  }

  Future<void> _loadWatchedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      watchedEpisodes = prefs.getStringList('watchedEpisodes')?.toSet() ?? {};
    });
  }

  Future<void> _markAsWatched(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    watchedEpisodes.add(episodeId);
    await prefs.setStringList('watchedEpisodes', watchedEpisodes.toList());
    setState(() {});
  }

  List<M3UContent> _getAllEpisodesInOrder() {
    final seasonKeys = widget.seasonsMap.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.compareTo(b);
      });

    final allEpisodes = <M3UContent>[];

    for (final season in seasonKeys) {
      final episodes = List<M3UContent>.from(widget.seasonsMap[season]!);
      episodes.sort((a, b) {
        final aEp = a.episodeNumber ?? 0;
        final bEp = b.episodeNumber ?? 0;
        return aEp.compareTo(bEp);
      });
      allEpisodes.addAll(episodes);
    }
    return allEpisodes;
  }

  Future<void> _navigateToPlayer(BuildContext context, M3UContent content) async {
    final allEpisodes = _getAllEpisodesInOrder();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TSPlayerScreenMobile(
          initialContent: content,
          playlist: allEpisodes,
          onEpisodeWatched: (episodeId) async {
            await _markAsWatched(episodeId);
            debugPrint("Episódio $episodeId marcado como assistido");
          },
        ),
      ),
    );

    await _loadWatchedEpisodes();
  }

  M3UContent? _findNextUnwatchedEpisode() {
    final allEpisodes = _getAllEpisodesInOrder();
    final nextEpisode = allEpisodes.firstWhereOrNull(
      (episode) => !watchedEpisodes.contains(episode.id),
    );
    return nextEpisode;
  }

  @override
  Widget build(BuildContext context) {
    // 3. Acessa o Notifier para saber se é favorito
    final favoritesNotifier = context.watch<FavoritesNotifier>();
    final isFavorite = favoritesNotifier.seriesFavorites.contains(widget.seriesName);

    final seasonKeys = widget.seasonsMap.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.compareTo(b);
      });

    final List<M3UContent> sortedEpisodes = selectedSeason != null
        ? (widget.seasonsMap[selectedSeason!]!
          ..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0)))
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 4,
        title: Text(
          widget.seriesName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 4. Implementação do Botão de Favorito
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? _highlightColor : Colors.white,
              size: 26,
            ),
            onPressed: () {
              // Chama o método toggleSeries do Notifier
              favoritesNotifier.toggleSeries(widget.seriesName);
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SeriesPosterHeader(
              seriesName: widget.seriesName,
              fallbackLogo: seriesLogo,
            ),
            
            const SizedBox(height: 20),
            
            Text(
              "Temporadas",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: seasonKeys.map((season) {
                  final isSelected = season == selectedSeason;

                  return GestureDetector(
                    onTap: () => setState(() => selectedSeason = season),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [
                                  _highlightColor,
                                  Color(0xFF00A3B5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade900,
                                  Colors.grey.shade800,
                                ],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _highlightColor.withOpacity(0.4), 
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        season,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "Episódios",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            if (selectedSeason != null)
              Column(
                children: sortedEpisodes.map((episode) {
                  final watched = watchedEpisodes.contains(episode.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade900,
                          Colors.grey.shade800.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ListTile(
                      onTap: () => _navigateToPlayer(context, episode),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _SeriesEpisodeThumbnail(
                          seriesName: widget.seriesName,
                          fallbackLogo: episode.logo,
                        ),
                      ),
                      title: Text(
                        episode.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        episode.group,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (episode.episodeNumber != null)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _highlightColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Ep ${episode.episodeNumber}",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          
                          if (watched)
                            const Icon(
                              Icons.remove_red_eye,
                              color: Color.fromARGB(255, 0, 255, 64),
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// WIDGETS AUXILIARES (POSTER E THUMBNAIL) - Mantidos iguais
// ====================================================================

class _SeriesPosterHeader extends StatefulWidget {
  final String seriesName;
  final String? fallbackLogo;

  const _SeriesPosterHeader({
    required this.seriesName,
    this.fallbackLogo,
  });

  @override
  State<_SeriesPosterHeader> createState() => _SeriesPosterHeaderState();
}

class _SeriesPosterHeaderState extends State<_SeriesPosterHeader> {
  String? _posterUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }
  
  @override
  void didUpdateWidget(covariant _SeriesPosterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesName != widget.seriesName || oldWidget.fallbackLogo != widget.fallbackLogo) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _posterUrl = null;
      });
    }
    
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
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(color: _highlightColor),
      );
    }

    final displayUrl = _posterUrl ?? widget.fallbackLogo;

    return Center(
      child: SizedBox(
        height: 200,
        width: 140,
        child: displayUrl != null
            ? Image.network(
                displayUrl,
                fit: BoxFit.cover,
                width: 140,
                height: 200,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: _highlightColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.tv_off, color: Colors.white38, size: 60),
                  ),
                ),
              )
            : Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(Icons.tv, color: Colors.white38, size: 60),
                ),
              ),
      ),
    );
  }
}

class _SeriesEpisodeThumbnail extends StatefulWidget {
  final String seriesName;
  final String? fallbackLogo;

  const _SeriesEpisodeThumbnail({
    required this.seriesName,
    this.fallbackLogo,
  });

  @override
  State<_SeriesEpisodeThumbnail> createState() => _SeriesEpisodeThumbnailState();
}

class _SeriesEpisodeThumbnailState extends State<_SeriesEpisodeThumbnail> {
  String? _posterUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }
  
  @override
  void didUpdateWidget(covariant _SeriesEpisodeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesName != widget.seriesName || oldWidget.fallbackLogo != widget.fallbackLogo) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _posterUrl = null;
      });
    }

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
        width: 65,
        height: 65,
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: _highlightColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final displayUrl = _posterUrl ?? widget.fallbackLogo;

    if (displayUrl == null) {
      return Container(
        width: 65,
        height: 65,
        color: Colors.grey.shade800,
        child: const Icon(Icons.tv, color: Colors.white38, size: 30),
      );
    }

    return Image.network(
      displayUrl,
      width: 65,
      height: 65,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 65,
        height: 65,
        color: Colors.grey.shade800,
        child: const Icon(Icons.tv_off, color: Colors.white38, size: 30),
      ),
    );
  }
}