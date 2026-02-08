import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart';

/// Player adaptado para HLS/.m3u8 ao vivo com overlay "AO VIVO" e fallback.
class LiveBetterPlayerScreen extends StatefulWidget {
  final M3UContent content;
  final List<M3UContent>? playlist;

  const LiveBetterPlayerScreen({super.key, required this.content, this.playlist});

  @override
  State<LiveBetterPlayerScreen> createState() => _LiveBetterPlayerScreenState();
}

class _LiveBetterPlayerScreenState extends State<LiveBetterPlayerScreen> {
  BetterPlayerController? _controller;
  Set<String> _watchedIds = {};
  late SharedPreferences _prefs;
  bool _isLoadingNext = false;
  M3UContent? _nextEpisode;
  bool _isCasting = false;

  @override
  void initState() {
    super.initState();
    _loadWatched();
    _findNextEpisode();
    _initializePlayer();
  }

  Future<void> _loadWatched() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getStringList('watchedEpisodes') ?? [];
    setState(() => _watchedIds = saved.toSet());
  }

  Future<void> _markAsWatched(String id) async {
    _watchedIds.add(id);
    await _prefs.setStringList('watchedEpisodes', _watchedIds.toList());
    setState(() {});
  }

  void _findNextEpisode() {
    if (widget.playlist == null) return;
    final currentIndex = widget.playlist!.indexWhere((item) => item.id == widget.content.id);
    if (currentIndex != -1 && currentIndex < widget.playlist!.length - 1) {
      _nextEpisode = widget.playlist![currentIndex + 1];
    }
  }

  bool _looksLikeLive(String url) {
    final low = url.toLowerCase();
    return low.contains('.m3u8') || low.contains('/live') || low.endsWith('.ts');
  }

  Future<void> _initializePlayer() async {
    final url = widget.content.url;
    final isLive = _looksLikeLive(url);

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: isLive,
      headers: {'User-Agent': 'Mozilla/5.0 (Flutter) BetterPlayer'},
      notificationConfiguration: BetterPlayerNotificationConfiguration(showNotification: false),
    );

    BetterPlayerConfiguration config = BetterPlayerConfiguration(
      autoPlay: true,
      aspectRatio: 16 / 9,
      allowedScreenSleep: !isLive,
      handleLifecycle: true,
      deviceOrientationsOnFullScreen: [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableFullscreen: true,
        enablePlaybackSpeed: !isLive,
        enableProgressBarDrag: !isLive,
        showControlsOnInitialize: true,
        enableSkips: !isLive,
      ),
    );

    _controller = BetterPlayerController(config);
    _controller!.addEventsListener(_onPlayerEvent);

    try {
      await _controller!.setupDataSource(dataSource);
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao iniciar BetterPlayer: $e');
      final fallback = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        liveStream: isLive,
      );
      try {
        await _controller!.setupDataSource(fallback);
      } catch (e2) {
        debugPrint('Fallback falhou: $e2');
      }
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.finished && !_isLoadingNext && _nextEpisode != null && !_isCasting) {
      _markAsWatched(widget.content.id);
      _playNextEpisode();
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      debugPrint('Player exception: ${event.parameters}');
    }
  }

  void _playNextEpisode() {
    if (_nextEpisode == null) return;

    setState(() => _isLoadingNext = true);
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveBetterPlayerScreen(content: _nextEpisode!, playlist: widget.playlist),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _looksLikeLive(widget.content.url);

    return Scaffold(
      appBar: AppBar(title: Text(widget.content.title), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      drawer: _buildEpisodeDrawer(),
      body: Center(
        child: _isCasting
            ? const Center(child: Text('Transmitindo para dispositivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))
            : _controller != null
                ? Stack(
                    children: [
                      AspectRatio(aspectRatio: 16 / 9, child: BetterPlayer(controller: _controller!)),
                      if (isLive)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.red,
                            child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  )
                : const CircularProgressIndicator(),
      ),
      floatingActionButton: _nextEpisode != null
          ? FloatingActionButton.extended(onPressed: _playNextEpisode, label: const Text('Próximo'), icon: const Icon(Icons.skip_next))
          : null,
    );
  }

  Widget _buildEpisodeDrawer() {
    if (widget.playlist == null) return const SizedBox.shrink();
    return Drawer(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.playlist!.length,
        itemBuilder: (context, index) {
          final episode = widget.playlist![index];
          final isWatched = _watchedIds.contains(episode.id);

          return ListTile(
            leading: episode.logo != null ? Image.network(episode.logo!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.tv)) : const Icon(Icons.tv),
            title: Text(episode.title),
            trailing: isWatched ? const Icon(Icons.remove_red_eye, color: Colors.green) : null,
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LiveBetterPlayerScreen(content: episode, playlist: widget.playlist))),
          );
        },
      ),
    );
  }
}
