import 'package:flutter/material.dart';
import '../models/content_model.dart';
import '../screens/serie_screen.dart';

class GroupSeriesScreen extends StatelessWidget {
  final String groupTitle;
  final Map<String, Map<String, List<M3UContent>>> seriesMap;
  final bool isMobile;

  const GroupSeriesScreen({
    super.key,
    required this.groupTitle,
    required this.seriesMap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final seriesList = seriesMap.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(groupTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Séries de "$groupTitle"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: seriesList.map((entry) {
              final seriesName = entry.key;
              final seasonsMap = entry.value;
              final firstItem = seasonsMap.values.first.first;
              final imageUrl = firstItem.logo;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SerieScreen(
                        seriesName: seriesName,
                        seasonsMap: seasonsMap,
                        isMobile: isMobile,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: isMobile ? 140 : 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: imageUrl != null && imageUrl.endsWith('.jpg')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                                ),
                              )
                            : Container(
                                color: Colors.grey[800],
                                child: const Center(child: Icon(Icons.tv, size: 40)),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        seriesName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${seasonsMap.length} temporada${seasonsMap.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
