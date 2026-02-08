import 'package:flutter/material.dart';
import '../models/content_model.dart';

class VideoCard extends StatelessWidget {
  final M3UContent content;
  final int width;
  final VoidCallback? onTap;

  const VideoCard({
    required this.content,
    required this.width,
    this.onTap,
    Key? key,
  }) : super(key: key);

  bool _isValidUrl(String? url) {
    if (url == null) return false;
    if (url.isEmpty) return false;
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = width >= 400;
    final imageHeight = width * 1.55;

    final imageUrl = _isValidUrl(content.logo)
        ? content.logo!
        : "https://via.placeholder.com/400x640.png?text=Sem+Capa";

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGEM
            SizedBox(
              height: imageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade900),
                      loadingBuilder: (context, child, loading) {
                        if (loading == null) return child;
                        return Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TEXTOS - SOLUÇÃO: Removido altura fixa e ajustado padding
            Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 4,
                top: 6,
                bottom: 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}