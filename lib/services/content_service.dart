import '../models/content_model.dart';
import 'zip_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive.dart';
import 'dart:typed_data';
import 'dart:convert';

class ContentService {
  /// Extrai e retorna apenas conteúdos de FILMES (sem duplicados)
  Future<List<M3UContent>> getMovieContent() async {
    final playlists = await ZipService.extractPlaylists();
    final filmesM3U = playlists['filmes']!;
    final parsed = parseM3U(filmesM3U);

    // Remove entradas que são reconhecidas como séries (S01E01 etc.)
    final seriesRegex = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,2})');
    final movies = parsed.where((item) => !seriesRegex.hasMatch(item.title)).toList();
    
    // Remove duplicados de filmes
    return _removeDuplicateMovies(movies);
  }

  /// Extrai e retorna apenas conteúdos de SÉRIES (sem duplicados)
  Future<List<M3UContent>> getSeriesContent() async {
    final playlists = await ZipService.extractPlaylists();
    final seriesM3U = playlists['series']!;
    final parsed = parseM3U(seriesM3U);
    
    // Remove duplicados de séries (incluindo versões com [L])
    return _removeDuplicateSeries(parsed);
  }

  /// Remove filmes duplicados baseado no título normalizado
  List<M3UContent> _removeDuplicateMovies(List<M3UContent> movies) {
    final Map<String, M3UContent> uniqueMovies = {};

    for (final movie in movies) {
      // Normaliza o título removendo espaços extras, pontos, traços e convertendo para minúsculo
      final normalizedTitle = _normalizeTitle(movie.title);

      // Mantém apenas o primeiro encontrado (ou você pode escolher o de melhor qualidade)
      if (!uniqueMovies.containsKey(normalizedTitle)) {
        uniqueMovies[normalizedTitle] = movie;
      }
    }

    return uniqueMovies.values.toList();
  }

  /// Remove séries duplicadas, incluindo versões com [L] no final
  List<M3UContent> _removeDuplicateSeries(List<M3UContent> series) {
    final Map<String, M3UContent> uniqueSeries = {};

    for (final serie in series) {
      // Remove o marcador [L] do final se existir
      String cleanTitle = serie.title.replaceAll(RegExp(r'\s*\[L\]\s*$'), '');
      
      // Normaliza o título
      final normalizedTitle = _normalizeTitle(cleanTitle);

      // Se já existe uma versão, verifica qual manter
      if (uniqueSeries.containsKey(normalizedTitle)) {
        // Prioriza a versão SEM [L] (geralmente é a original)
        final existingHasL = uniqueSeries[normalizedTitle]!.title.contains('[L]');
        final currentHasL = serie.title.contains('[L]');
        
        // Se a existente tem [L] e a atual não, substitui
        if (existingHasL && !currentHasL) {
          uniqueSeries[normalizedTitle] = serie;
        }
        // Se ambas não têm [L] ou ambas têm, mantém a primeira
      } else {
        uniqueSeries[normalizedTitle] = serie;
      }
    }

    return uniqueSeries.values.toList();
  }

  /// Normaliza o título para comparação
  /// Remove caracteres especiais, espaços extras e converte para minúsculo
  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .trim()
        // Remove múltiplos espaços
        .replaceAll(RegExp(r'\s+'), ' ')
        // Remove pontos, traços e underscores no final/início
        .replaceAll(RegExp(r'^[.\-_\s]+|[.\-_\s]+$'), '')
        // Substitui pontos, traços e underscores por espaço
        .replaceAll(RegExp(r'[.\-_]'), ' ')
        // Remove espaços duplicados novamente
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extrai e retorna conteúdos de TV ao vivo a partir do ZIP "tv_aovivo.zip"
  Future<List<M3UContent>> getLiveTvContent() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tv_aovivo.zip');
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());

      List<M3UContent> liveTvContents = [];
      int idCounter = 0;

      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.m3u')) {
          final contentString = utf8.decode(file.content as List<int>);
          final parsed = parseM3U(contentString);

          // Adiciona um id único para cada canal
          parsed.forEach((item) {
            liveTvContents.add(M3UContent(
              id: 'live_${idCounter++}',
              title: item.title,
              url: item.url,
              logo: item.logo,
              group: item.group.isNotEmpty ? item.group : 'Sem grupo',
              description: item.description,
            ));
          });
        }
      }

      // Remove duplicados de canais de TV
      return _removeDuplicateTvChannels(liveTvContents);
    } catch (e) {
      throw Exception('Erro ao carregar TV ao vivo: ${e.toString()}');
    }
  }

  /// Remove canais de TV duplicados
  List<M3UContent> _removeDuplicateTvChannels(List<M3UContent> channels) {
    final Map<String, M3UContent> uniqueChannels = {};

    for (final channel in channels) {
      final normalizedTitle = _normalizeTitle(channel.title);

      if (!uniqueChannels.containsKey(normalizedTitle)) {
        uniqueChannels[normalizedTitle] = channel;
      }
    }

    return uniqueChannels.values.toList();
  }

  /// Categoriza os FILMES por grupo (ex: ação, comédia)
  Future<Map<String, List<M3UContent>>> getMovieCategories() async {
    final movies = await getMovieContent();
    final Map<String, List<M3UContent>> categorized = {};

    for (final item in movies) {
      final category = item.group;
      categorized.putIfAbsent(category, () => []);
      categorized[category]!.add(item);
    }

    return categorized;
  }

  /// Categoriza as SÉRIES por grupo (caso deseje exibir sem separar por temporada)
  Future<Map<String, List<M3UContent>>> getSeriesCategories() async {
    final series = await getSeriesContent();
    final Map<String, List<M3UContent>> categorized = {};

    for (final item in series) {
      final category = item.group;
      categorized.putIfAbsent(category, () => []);
      categorized[category]!.add(item);
    }

    return categorized;
  }

  /// Agrupa séries por nome e temporada (S01E01, S01E02 etc.)
  /// Remove completamente séries com [L] e duplicados
  Future<Map<String, Map<String, List<M3UContent>>>> getSeriesGroupedBySeason() async {
    final series = await getSeriesContent();
    final Map<String, Map<String, List<M3UContent>>> grouped = {};
    final regex = RegExp(r'^(.*?)[\s._-]*[Ss](\d{1,2})[Ee](\d{1,2})');

    for (final item in series) {
      // Ignora completamente episódios com [L] no título
      if (item.title.contains('[L]')) continue;
      
      final match = regex.firstMatch(item.title);
      if (match != null) {
        String seriesName = match.group(1)?.trim() ?? 'Série Desconhecida';
        final season = 'Temporada ${match.group(2)}';
        final episode = match.group(3);

        grouped.putIfAbsent(seriesName, () => {});
        grouped[seriesName]!.putIfAbsent(season, () => []);
        
        // Verifica se já existe este episódio nesta temporada
        final episodeKey = 'S${match.group(2)}E$episode';
        final alreadyExists = grouped[seriesName]![season]!.any(
          (ep) => ep.title.contains(episodeKey)
        );

        // Se não existe ainda, adiciona
        if (!alreadyExists) {
          grouped[seriesName]![season]!.add(item);
        }
      }
    }

    // Ordena os episódios dentro de cada temporada
    grouped.forEach((seriesName, seasons) {
      seasons.forEach((seasonName, episodes) {
        episodes.sort((a, b) {
          final regexEp = RegExp(r'[Ss]\d{1,2}[Ee](\d{1,2})');
          final matchA = regexEp.firstMatch(a.title);
          final matchB = regexEp.firstMatch(b.title);
          
          if (matchA != null && matchB != null) {
            final epA = int.parse(matchA.group(1)!);
            final epB = int.parse(matchB.group(1)!);
            return epA.compareTo(epB);
          }
          return 0;
        });
      });
    });

    return grouped;
  }

  /// Parser de conteúdo M3U → List<M3UContent>
  List<M3UContent> parseM3U(String m3uString) {
    final lines = m3uString.split('\n');
    final List<M3UContent> contents = [];
    int idCounter = 0;

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      if (line.startsWith('#EXTINF')) {
        final tvgNameMatch = RegExp(r'tvg-name="([^"]*)"').firstMatch(line);
        final tvgName = tvgNameMatch?.group(1) ?? '';
        if (tvgName.startsWith('[XXX]')) continue;

        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        final group = groupMatch?.group(1) ?? '';
        if (group.toLowerCase() == 'adulto') continue;

        final url = lines[i + 1].trim();
        final titleMatch = RegExp(r'#EXTINF.*?,\s*(.+)').firstMatch(line);
        final logoMatch = RegExp(r'tvg-logo="(.*?)"').firstMatch(line);

        contents.add(M3UContent(
          id: 'content_${idCounter++}',
          title: titleMatch?.group(1) ?? 'Sem título',
          url: url,
          logo: logoMatch?.group(1),
          group: group.isNotEmpty ? group : 'Sem grupo',
          description: '',
        ));
      }
    }

    return contents;
  }
}