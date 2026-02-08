import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import '../models/content_model.dart';
import 'better_player.dart';

class LiveTvScreen extends StatefulWidget {
  final bool isMobile;

  const LiveTvScreen({super.key, required this.isMobile});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, M3UContent> _channels = {};
  final Map<String, bool> _favorites = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadChannels();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    setState(() {
      for (var key in keys) {
        if (key.startsWith('fav_tv_')) {
          _favorites[key.replaceFirst('fav_tv_', '')] = prefs.getBool(key) ?? false;
        }
      }
    });
  }

  Future<void> _saveFavorite(String channelName, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fav_tv_$channelName', value);
  }

  Future<void> _loadChannels() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tv_aovivo.zip');
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());

      final Map<String, M3UContent> loadedChannels = {};

      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase().endsWith('.m3u')) {
          final contentString = utf8.decode(file.content as List<int>);
          final lines = LineSplitter.split(contentString).toList();

          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i];
            if (line.startsWith('#EXTINF')) {
              final title = line.split(',').last.trim();
              final url = lines[i + 1].trim();
              loadedChannels[title] = M3UContent(
                id: 'tv_$i',
                title: title,
                url: url,
                logo: null,
                group: 'TV ao vivo',
                description: '',
              );
            }
          }
        }
      }

      setState(() {
        _channels.clear();
        _channels.addAll(loadedChannels);

        for (var title in _channels.keys) {
          if (!_favorites.containsKey(title)) _favorites[title] = false;
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar TV ao vivo: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _toggleFavorite(String channelName) {
    setState(() {
      _favorites[channelName] = !_favorites[channelName]!;
      _saveFavorite(channelName, _favorites[channelName]!);
    });
  }

  List<String> _filterChannels(String query) {
    List<String> filtered = _channels.keys
        .where((title) => title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    filtered.sort((a, b) {
      if (_favorites[a]! && !_favorites[b]!) return -1;
      if (!_favorites[a]! && _favorites[b]!) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    return filtered;
  }

  void _playChannel(M3UContent channel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveBetterPlayerScreen(content: channel)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filteredChannels = _filterChannels(_searchController.text);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('TV ao vivo'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 108, 9, 229),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color.fromARGB(255, 108, 9, 229),
              decoration: InputDecoration(
                hintText: 'Buscar canais...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Color.fromARGB(255, 108, 9, 229)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color.fromARGB(255, 108, 9, 229)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 108, 9, 229), width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                        ),
                      )
                    : _buildChannelList(filteredChannels),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(List<String> channelList) {
    if (channelList.isEmpty) {
      return const Center(
        child: Text('Nenhum canal encontrado', style: TextStyle(color: Colors.white70, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: channelList.length,
      itemBuilder: (context, index) {
        final channelName = channelList[index];
        final channel = _channels[channelName]!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: InkWell(
            onTap: () => _playChannel(channel),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: channel.logo != null
                        ? Image.network(channel.logo!, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                        : _buildPlaceholder(),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black54,
                      child: Text(channel.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(channelName),
                      child: Icon(_favorites[channelName]! ? Icons.star : Icons.star_border, color: _favorites[channelName]! ? Colors.amber : Colors.white70, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Icon(Icons.tv, size: 64, color: Colors.white54)),
    );
  }
}