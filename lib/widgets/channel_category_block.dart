// Arquivo: channel_category_block_circular.dart
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/sheets_services.dart';

const String _channelImgViewTypeBase = 'channel-category-circular-img-';

class ChannelCategoryBlockCircular extends StatelessWidget {
  final String category;
  final List<ChannelData> channels;
  final VoidCallback onSeeAll;
  final Function(ChannelData)? onItemTap;
  final bool Function(String name)? isFavorite;
  final Function(String name)? onToggleFavorite;
  final Color barColor;

const ChannelCategoryBlockCircular({
    super.key,
    required this.category,
    required this.channels,
    required this.barColor, // NOVO
    required this.onSeeAll,
    required this.onItemTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  Widget _buildChannelImage(String url, ChannelData channel, double size) {
    // VARIÁVEL PARA CONTROLE DO ZOOM: Aumente este valor para diminuir o zoom da imagem.
    const double _imagePadding = 8.0; 

    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.tv, color: Colors.white38, size: 40),
        ),
      );
    }

    if (kIsWeb) {
      final uniqueId = '$_channelImgViewTypeBase${url.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      
      ui_web.platformViewRegistry.registerViewFactory(uniqueId, (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          // Mantido como 'contain' para caber no Padding
          ..style.objectFit = 'contain'
          ..style.borderRadius = '0%' // Retiramos o borderRadius aqui pois o ClipOval já faz o trabalho
          ..style.cursor = 'pointer';
        
        img.onClick.listen((_) {
          if (onItemTap != null) {
            onItemTap!(channel);
          }
        });
        
        // O elemento HTML deve ser retornado sem Padding no Factory
        return img;
      });

      // NOVO: Adiciona Padding ao redor do HtmlElementView para simular o zoom-out
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: const EdgeInsets.all(_imagePadding), // AQUI
          child: HtmlElementView(viewType: uniqueId),
        ),
      );
    }

    // Flutter Nativo
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white, // Fundo para a imagem que pode não preencher todo o espaço
          // NOVO: Adiciona Padding ao redor da imagem para simular o zoom-out
          child: Padding(
            padding: const EdgeInsets.all(_imagePadding), // AQUI
            child: Image.network(
              url,
              // Mantido como 'contain' para caber no Padding sem cortar
              fit: BoxFit.contain, 
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
                      strokeWidth: 2,
                      color: const Color(0xFFE50914),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.tv_off,
                    size: 40,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header com título e "Ver tudo"
        if (category.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      color: barColor,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 108, 9, 229),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${channels.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'Ver Tudo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Lista horizontal de círculos
        SizedBox(
          height: circleSize + 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final channel = channels[index];
              final isFav = isFavorite?.call(channel.name) ?? false;

              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 16 : 8,
                  right: index == channels.length - 1 ? 16 : 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (onItemTap != null) {
                      onItemTap!(channel);
                    }
                  },
                  child: SizedBox(
                    width: circleSize,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Card circular com imagem
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: circleSize,
                              height: circleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Container(
                                  color: Colors.white,
                                  child: _buildChannelImage(
                                    channel.imageUrl,
                                    channel,
                                    circleSize,
                                  ),
                                ),
                              ),
                            ),
                            // Botão de favorito
                            if (onToggleFavorite != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => onToggleFavorite!(channel.name),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isFav ? Icons.star : Icons.star_border,
                                      color: isFav ? Colors.green : Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Nome do canal
                        Text(
                          channel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}