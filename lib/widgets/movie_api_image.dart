import 'package:flutter/material.dart';
import '../models/content_model.dart';

const Color _movieColor = Color(0xFFFF5252); // Vermelho para Filmes

/// Widget reutilizável para exibir capas de filmes via TMDB
class MovieApiImage extends StatefulWidget {
  final String movieTitle;
  final String? fallbackLogo;
  final BoxFit fit;
  final double? width;
  final double? height;

  const MovieApiImage({
    Key? key,
    required this.movieTitle,
    this.fallbackLogo,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<MovieApiImage> createState() => _MovieApiImageState();
}

class _MovieApiImageState extends State<MovieApiImage> {
  String? _posterUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  @override
  void didUpdateWidget(covariant MovieApiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarrega apenas se o título mudou
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
      // Busca a capa via TMDB
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
      print('Erro ao carregar poster: $e');
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
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_filter_rounded,
          color: Colors.white38,
          size: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: _movieColor,
              strokeWidth: 2.5,
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
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: 500, // Otimiza cache
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey[900]!,
                Colors.grey[850]!,
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2.5,
              color: _movieColor,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildFallbackImage(),
    );
  }
}