import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/sheets_services.dart'; // Importe seu modelo ChannelData aqui

class ChannelPlayerScreen extends StatefulWidget {
  final ChannelData channel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const ChannelPlayerScreen({
    super.key,
    required this.channel,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<ChannelPlayerScreen> createState() => _ChannelPlayerScreenState();
}

class _ChannelPlayerScreenState extends State<ChannelPlayerScreen> {
  late String _viewId;
  late bool _localIsFavorite;

  @override
  void initState() {
    super.initState();
    _localIsFavorite = widget.isFavorite;
    // Cria um ID único para este Iframe baseada na URL e no tempo atual para evitar cache de view
    _viewId = 'iframe-${widget.channel.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  /// Registra o IFrame do player na PlatformViewRegistry (apenas para Web)
  void _registerView() {
    if (kIsWeb) {
      // Registra a factory do elemento HTML
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final iframe = html.IFrameElement()
          ..id = 'iframe-element-${widget.channel.name}'
          ..style.border = '0'
          ..allowFullscreen = true
          // ATENÇÃO: Usa a URL do ChannelData para o SRC do Iframe
          ..src = widget.channel.url;
        return iframe;
      });
    }
  }

  /// Gerencia o toque no ícone de favorito
  void _handleFavoriteTap() {
    setState(() {
      _localIsFavorite = !_localIsFavorite;
    });
    // Chama a função da tela pai para salvar no SharedPreferences
    widget.onToggleFavorite();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 108, 9, 229),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.channel.name,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _localIsFavorite ? Icons.star : Icons.star_border,
              color: _localIsFavorite ? Colors.lightGreen : Colors.white,
            ),
            onPressed: _handleFavoriteTap,
          ),
        ],
      ),
      body: kIsWeb
          ? HtmlElementView(viewType: _viewId)
          : const Center(
              child: Text(
                "Player disponível apenas na Web.",
                style: TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}