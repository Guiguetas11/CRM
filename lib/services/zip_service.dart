import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:hive/hive.dart';

class ZipService {
  static const String filmesBoxName = 'playlist_filmes_box';
  static const String seriesBoxName = 'playlist_series_box';
  static const String tvLiveBoxName = 'playlist_tv_live_box';
  static const String imagesBoxName = 'playlist_images_box'; // Nova Box

  static const String filmesKey = 'filmes';
  static const String seriesKey = 'series';
  static const String tvLiveKey = 'tv_live';
  static const String imagesKey = 'images'; // Nova chave

  // Extrai e salva no Hive, ou lê do Hive se cache existir
  static Future<Map<String, String>> extractPlaylists() async {
    try {
      var filmesBox = await Hive.openBox<String>(filmesBoxName);
      var seriesBox = await Hive.openBox<String>(seriesBoxName);
      

      String? filmes = filmesBox.get(filmesKey);
      String? series = seriesBox.get(seriesKey);
      

      if (filmes != null && series != null ) {
        return {'filmes': filmes, 'series': series, };
      } else {
        filmes = await _extractCleanedM3U('assets/playlist_filmes.zip');
        series = await _extractCleanedM3U('assets/playlist_series.zip');
        

        await filmesBox.put(filmesKey, filmes);
        await seriesBox.put(seriesKey, series);
        

        return {'filmes': filmes, 'series': series, };
      }
    } catch (e) {
      throw Exception('Falha ao extrair playlists: ${e.toString()}');
    }
  }

  // Limpar cache
  static Future<void> clearCache() async {
    var filmesBox = await Hive.openBox<String>(filmesBoxName);
    var seriesBox = await Hive.openBox<String>(seriesBoxName);

    await filmesBox.clear();
    await seriesBox.clear();

  }

  static Future<String> _extractCleanedM3U(String zipAssetPath) async {
    final bytes = await rootBundle.load(zipAssetPath);
    final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());

    final m3uEntry = archive.files.firstWhere(
      (file) => file.name.toLowerCase().endsWith('.m3u'),
      orElse: () => throw Exception('Arquivo M3U não encontrado no ZIP: $zipAssetPath'),
    );

    final raw = utf8.decode(m3uEntry.content as List<int>);
    final lines = LineSplitter.split(raw).toList();

    final Set<String> seenUrls = {};
    final List<String> cleanedLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXTINF')) {
        final nextLine = (i + 1 < lines.length) ? lines[i + 1] : '';
        final containsAdultoOuDiversos = line.toLowerCase().contains('adulto') ||
            line.toLowerCase().contains('diverso');

        if (!containsAdultoOuDiversos && !seenUrls.contains(nextLine)) {
          cleanedLines.add(line);
          cleanedLines.add(nextLine);
          seenUrls.add(nextLine);
        }
      }
    }

    return cleanedLines.join('\n');
  }
}

