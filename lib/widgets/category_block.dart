import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content_model.dart';
import '../widgets/movie_api_image.dart';
import '../services/favorites_notifier.dart';

class CategoryBlock extends StatelessWidget {
  final String category;
  final List<M3UContent> contents;
  final VoidCallback onSeeAll;
  final Function(M3UContent)? onItemTap;
  final bool isMovies;

  const CategoryBlock({
    required this.category,
    required this.contents,
    required this.onSeeAll,
    this.onItemTap,
    this.isMovies = true,
    Key? key,
  }) : super(key: key);

  int _getColumnsCount(double screenWidth) {
    if (screenWidth < 600) {
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

  double _getCardWidth(double screenWidth, int columns) {
    final padding = 16.0 * 2;
    final spacing = 12.0 * (columns - 1);
    return (screenWidth - padding - spacing) / columns;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumnsCount(screenWidth);
    final cardWidth = _getCardWidth(screenWidth, columns);
    final cardHeight = cardWidth * 1.5;

    return Consumer<FavoritesNotifier>(
      builder: (context, favNotifier, child) {
        final favorites = isMovies 
            ? favNotifier.movieFavorites 
            : favNotifier.seriesFavorites;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFB20710)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          margin: const EdgeInsets.only(right: 12),
                        ),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFE50914), Color(0xFFB20710)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  child: GestureDetector(
    onTap: onSeeAll,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Ver tudo',
          style: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(width: 4),
      ],
    ),
  ),
)
                  ],
                ),
              ),

            SizedBox( 
              height: cardHeight + 10,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: contents.length,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final content = contents[index];
                  final isFav = favorites.contains(content.title);

                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == contents.length - 1 ? 0 : 12,
                    ),
                    child: GestureDetector(
                      onTap: () => onItemTap?.call(content),
                      child: Container( 
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MovieApiImage(
                                movieTitle: content.title,
                                fallbackLogo: content.logo,
                                fit: BoxFit.cover,
                                width: cardWidth,
                                height: cardHeight,
                              ),

                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: cardHeight * 0.4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.6),
                                        Colors.black.withOpacity(0.9),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      content.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: cardWidth < 120 ? 13 : 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      content.group,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: cardWidth < 120 ? 11 : 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: cardWidth < 120 ? 24 : 32,
                                  ),
                                ),
                              ),

                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    if (isMovies) {
                                      favNotifier.toggleMovie(content.title);
                                    } else {
                                      favNotifier.toggleSeries(content.title);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isFav
                                            ? Colors.red.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      isFav ? Icons.favorite : Icons.favorite_border,
                                      color: isFav ? Colors.red : Colors.white,
                                      size: cardWidth < 120 ? 16 : 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}