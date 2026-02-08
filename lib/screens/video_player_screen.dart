import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart';

class VideoPlayerScreen extends StatefulWidget {
  final M3UContent content;
  final List<M3UContent>? playlist;

  const VideoPlayerScreen({
    super.key,
    required this.content,
    this.playlist,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoadingNext = false;
  M3UContent? _nextEpisode;
  final bool _isCasting = false;

  // Controle de visibilidade da interface
  bool _showControls = true;
  Timer? _hideTimer;

  Set<String> _watchedIds = {};
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _setFullScreen();
    _loadWatched();
    _initializePlayer();
    _findNextEpisode();
    _startHideTimer(); // Inicia o timer para esconder controles
  }

  void _setFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadWatched() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getStringList("watchedEpisodes") ?? [];
    setState(() {
      _watchedIds = saved.toSet();
    });
  }

  Future<void> _markAsWatched(String id) async {
    _watchedIds.add(id);
    await _prefs.setStringList("watchedEpisodes", _watchedIds.toList());
    setState(() {});
  }

  void _findNextEpisode() {
    if (widget.playlist == null) return;
    final currentIndex =
        widget.playlist!.indexWhere((item) => item.id == widget.content.id);
    if (currentIndex != -1 && currentIndex < widget.playlist!.length - 1) {
      _nextEpisode = widget.playlist![currentIndex + 1];
    }
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.content.url))
      ..addListener(_videoListener);

    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController.value.aspectRatio,
      autoInitialize: true,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: true,
      // IMPORTANTE: Desativamos os controles nativos para usar o nosso overlay unificado
      showControls: false, 
    );

    setState(() {});
  }

  void _videoListener() {
    // Listener apenas para lógica de fim de vídeo
    if (_videoController.value.position >=
        _videoController.value.duration - const Duration(seconds: 1)) {
      if (!_isLoadingNext && _nextEpisode != null && !_isCasting) {
        _markAsWatched(widget.content.id);
        _playNextEpisode();
      }
    }
  }

  // --- Lógica de Controle de Interface ---
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onTapScreen() {
    _toggleControls();
  }
  // ---------------------------------------

  void _playNextEpisode() {
    if (_nextEpisode == null) return;

    setState(() => _isLoadingNext = true);

    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _chewieController?.dispose();
    _hideTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          content: _nextEpisode!,
          playlist: widget.playlist,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _chewieController?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _onTapScreen, // Detecta toque em qualquer lugar para mostrar/esconder
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. O Player de Vídeo (Sem controles nativos)
              Center(
                child: _chewieController != null &&
                        _chewieController!.videoPlayerController.value.isInitialized &&
                        !_isCasting
                    ? Chewie(controller: _chewieController!)
                    : _isCasting
                        ? const Center(
                            child: Text(
                              'Transmitindo para dispositivo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const CircularProgressIndicator(color: Colors.red),
              ),

              // 2. Camada de Controles Unificada (Fade In/Out)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls, // Impede cliques quando invisível
                  child: Container(
                    color: Colors.black26, // Leve escurecida para ler os botões
                    child: Stack(
                      children: [
                        // Botão Play/Pause Central
                        if (_chewieController != null)
                          Center(
                            child: ValueListenableBuilder(
                              valueListenable: _videoController,
                              builder: (context, VideoPlayerValue value, child) {
                                return IconButton(
                                  iconSize: 64,
                                  color: Colors.white,
                                  icon: Icon(
                                    value.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                  ),
                                  onPressed: () {
                                    if (value.isPlaying) {
                                      _videoController.pause();
                                    } else {
                                      _videoController.play();
                                    }
                                    _startHideTimer(); // Reseta o timer ao interagir
                                  },
                                );
                              },
                            ),
                          ),

                        // Barra Superior (Voltar e Playlist)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                onPressed: () => Navigator.pop(context),
                              ),
                              if (widget.playlist != null)
                                IconButton(
                                  icon: const Icon(Icons.list, color: Colors.white, size: 28),
                                  onPressed: () => _showEpisodeList(),
                                ),
                            ],
                          ),
                        ),

                        // Barra Inferior (Slider de Progresso)
                        if (_chewieController != null)
                          Positioned(
                            bottom: 20,
                            left: 16,
                            right: 16,
                            child: ValueListenableBuilder(
                              valueListenable: _videoController,
                              builder: (context, VideoPlayerValue value, child) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.red,
                                        inactiveTrackColor: Colors.grey,
                                        thumbColor: Colors.red,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      ),
                                      child: Slider(
                                        min: 0,
                                        max: value.duration.inMilliseconds.toDouble(),
                                        value: value.position.inMilliseconds.toDouble().clamp(0, value.duration.inMilliseconds.toDouble()),
                                        onChanged: (newValue) {
                                          _hideTimer?.cancel(); // Para o timer enquanto arrasta
                                          setState(() {}); // Atualiza visualmente
                                        },
                                        onChangeEnd: (newValue) {
                                          _videoController.seekTo(Duration(milliseconds: newValue.toInt()));
                                          _startHideTimer(); // Retoma o timer
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodeList() {
    // Pausa o timer ao abrir o modal para não bugar a UI
    _hideTimer?.cancel();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Episódios',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.playlist!.length,
                itemBuilder: (context, index) {
                  final episode = widget.playlist![index];
                  final isWatched = _watchedIds.contains(episode.id);

                  return ListTile(
                    leading: episode.logo != null
                        ? Image.network(
                            episode.logo!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.tv,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.tv, color: Colors.white),
                    title: Text(
                      episode.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: isWatched
                        ? const Icon(Icons.remove_red_eye, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            content: episode,
                            playlist: widget.playlist,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Retoma o timer quando fecha o modal
      _startHideTimer();
    });
  }
}