import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ZipPlaylistScreen extends StatefulWidget {
  const ZipPlaylistScreen({Key? key}) : super(key: key);

  @override
  State<ZipPlaylistScreen> createState() => _ZipPlaylistScreenState();
}

class _ZipPlaylistScreenState extends State<ZipPlaylistScreen> {
  List<String> _streamUrls = [];
  bool _isLoading = true;
  String? _error;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _loadAndParseZip();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _loadAndParseZip() async {
    try {
      final bytes = await rootBundle.load('assets/playlist.zip');
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());

      final m3uEntry = archive.files.firstWhere(
        (file) => file.name.toLowerCase().endsWith('.m3u'),
        orElse: () => throw Exception('Arquivo M3U não encontrado no ZIP'),
      );

      final raw = utf8.decode(m3uEntry.content as List<int>);
      final lines = LineSplitter.split(raw).toList();

      // Limpar duplicados e extrair só URLs válidas para stream
      final Set<String> seenUrls = {};
      final List<String> urls = [];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        if (!seenUrls.contains(line) &&
            (line.endsWith('.m3u8') || line.endsWith('.mp4') || line.endsWith('.ts'))) {
          urls.add(line);
          seenUrls.add(line);
        }
      }

      setState(() {
        _streamUrls = urls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar playlist: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _playVideo(String url) async {
    // Dispose controllers anteriores
     _videoController?.dispose();
     _chewieController?.dispose();

    _videoController = VideoPlayerController.network(url);

    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowMuting: true,
      // Ajuste conforme preferir:
      aspectRatio: _videoController!.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Erro no vídeo: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );

    setState(() {});

    // Abrir modal para o player
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _chewieController?.pause();
              Navigator.pop(context);
            },
            child: const Text('Fechar'),
          ),
        ],
      ),
    ).then((_) {
      // Dispose ao fechar modal
      _videoController?.pause();
      _chewieController?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist ZIP')),
        body: Center(child: Text(_error!)),
      );
    }

    if (_streamUrls.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist ZIP')),
        body: const Center(child: Text('Nenhum stream encontrado na playlist.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Streams da Playlist')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _streamUrls.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final url = _streamUrls[index];
          return ListTile(
            title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => _playVideo(url),
          );
        },
      ),
    );
  }
}
