import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:chewie/chewie.dart'; 

import '../models/content_model.dart';

const Color _primaryColor = Color(0xFF00E5FF);

class TSPlayerScreenMobile extends StatefulWidget {
  final M3UContent initialContent;
  final List<M3UContent> playlist;
  final Future<void> Function(String episodeId)? onEpisodeWatched;

  const TSPlayerScreenMobile({
    super.key,
    required this.initialContent,
    required this.playlist,
    this.onEpisodeWatched,
  });

  @override
  State<TSPlayerScreenMobile> createState() => _TSPlayerScreenMobileState();
}

class _TSPlayerScreenMobileState extends State<TSPlayerScreenMobile> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  
  bool _initialized = false;
  String _status = '';
  late M3UContent _current;

  bool _hasAdvanced = false;
  bool _isLoadingNext = false;
  M3UContent? _nextEpisode;
  
  late SharedPreferences _prefs;
  Set<String> _watchedIds = {};

  final Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/50 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    _current = widget.initialContent;
    
    _loadData();
  }

  @override
  void dispose() {
    
    // RESTAURAÇÃO DO SISTEMA
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    
    _disposeController();
    super.dispose();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getStringList("watchedEpisodes") ?? [];
    
    if (mounted) {
      setState(() => _watchedIds = saved.toSet());
      _findNextEpisode();
      _initControllerFor(_current);
    }
  }

  Future<void> _markAsWatched(String id) async {
    if (_watchedIds.contains(id)) return;
    _watchedIds.add(id);
    await _prefs.setStringList("watchedEpisodes", _watchedIds.toList());
    widget.onEpisodeWatched?.call(id);
    if (mounted) setState(() {});
  }

  void _findNextEpisode() {
    final idx = widget.playlist.indexWhere((e) => e.id == _current.id);
    if (idx >= 0 && idx < widget.playlist.length - 1) {
      _nextEpisode = widget.playlist[idx + 1];
    } else {
      _nextEpisode = null;
    }
  }

  Future<void> _disposeController() async {
    if (_videoController == null) return;
    _videoController!.removeListener(_controllerListener);
    // ⚠️ REMOVIDO: O listener _fullscreenListener foi removido daqui
    
    _chewieController?.dispose(); 

    try {
      await _videoController!.pause();
      await _videoController!.dispose();
    } catch (_) {}
    _videoController = null;
  }

  Future<void> _initControllerFor(M3UContent content) async {
    await _disposeController();
    if (!mounted) return;

    setState(() {
      _initialized = false;
      _status = 'Carregando...';
      _hasAdvanced = false;
      _isLoadingNext = false;
    });

    try {
      final url = content.url.trim();
      if (url.isEmpty) {
        setState(() => _status = 'URL vazia');
        return;
      }

      // 1. Inicialização do VideoPlayerController
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _defaultHeaders,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoController!.initialize();
      _videoController!.addListener(_controllerListener);
      
      // ⚠️ REMOVIDO: Removemos a adição do listener que causava a reconstrução extra
      // _videoController!.addListener(_fullscreenListener); 


      // 2. Configuração do ChewieController 
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: _videoController!.value.aspectRatio, 
        autoPlay: true,
        looping: false,
        
        showControls: true, 

        // CONFIGURAÇÃO CHAVE PARA EVITAR RECONSTRUÇÃO:
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],

        // Configurações de UI
        allowFullScreen: true,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _primaryColor, 
          handleColor: _primaryColor,
          backgroundColor: Colors.white.withOpacity(0.3),
          bufferedColor: Colors.white54,
        ),
        showControlsOnInitialize: true,
        autoInitialize: true,
      );

      if (mounted) {
        setState(() {
          _initialized = true;
          _status = 'Pronto';
        });
      }
      
      _findNextEpisode();
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Erro ao carregar vídeo');
      }
    }
  }


  // ⚠️ REMOVIDO: O método _fullscreenListener foi removido


  void _controllerListener() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.hasError) {
      if (!_status.startsWith('Erro:')) {
        setState(() => _status = 'Erro: ${c.value.errorDescription}');
      }
      return;
    }

    final pos = c.value.position;
    final dur = c.value.duration;
    
    // Lógica de Avançar Automaticamente (Mantida)
    if (!_hasAdvanced && dur.inSeconds > 0 && pos.inSeconds >= (dur.inSeconds - 1)) {
      _hasAdvanced = true;
      if (!_isLoadingNext && _nextEpisode != null) {
        _markAsWatched(_current.id);
        _advanceToNext();
      }
    }
  }

  void _advanceToNext() {
    if (_isLoadingNext) return;
    final idx = widget.playlist.indexWhere((e) => e.id == _current.id);
    if (idx >= 0 && idx < widget.playlist.length - 1) {
      final next = widget.playlist[idx + 1];
      setState(() => _isLoadingNext = true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TSPlayerScreenMobile(
            initialContent: next,
            playlist: widget.playlist,
            onEpisodeWatched: widget.onEpisodeWatched,
          ),
        ),
      );
    }
  }

  void _goPrevious() {
    final idx = widget.playlist.indexWhere((e) => e.id == _current.id);
    if (idx > 0) {
      final prev = widget.playlist[idx - 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TSPlayerScreenMobile(
            initialContent: prev,
            playlist: widget.playlist,
            onEpisodeWatched: widget.onEpisodeWatched,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    if (!_initialized || _chewieController == null || !_chewieController!.videoPlayerController.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 3,
              ),
              if (_status.isNotEmpty && _status != 'Carregando...' && _status != 'Pronto')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    // 🟢 CHECA O ESTADO: O estado é verificado no build.
    // Quando o Chewie sai do fullscreen, o Flutter reconstrói a tela
    // naturalmente, e esta variável reflete o estado correto.
    final isFullScreen = _chewieController?.isFullScreen ?? false;


    return Scaffold(
      backgroundColor: Colors.black,
      // APPBAR CONDICIONAL: 
      // Mostra apenas se NÃO estiver em Fullscreen.
      appBar: isFullScreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              // Botão de voltar
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // TÍTULO: Nome do episódio (visível apenas fora do fullscreen)
              title: Text(
                _current.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
      
      body: Center(
        child: Chewie(
          controller: _chewieController!,
        ),
      ),
    );
  }
}