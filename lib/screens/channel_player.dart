// screens/channel_player_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class ChannelPlayerScreen extends StatefulWidget {
  final String channelName;
  final String embedUrl;

  const ChannelPlayerScreen({
    super.key,
    required this.channelName,
    required this.embedUrl,
  });

  @override
  State<ChannelPlayerScreen> createState() => _ChannelPlayerScreenState();
}

class _ChannelPlayerScreenState extends State<ChannelPlayerScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  
  // Cor primária do seu app
  static const Color primaryColor = Color.fromARGB(255, 108, 9, 229); 

  @override
  void initState() {
    super.initState();

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
             setState(() => _progress = 0.0);
          },
          onPageFinished: (String url) {
             setState(() => _progress = 1.0);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erro de recurso: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));

    // Permite que players de mídia comecem sem interação do usuário (autoplay) no Android
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channelName),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Exibe o Player/Embed
          WebViewWidget(controller: _controller),

          // Barra de progresso
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
            ),
        ],
      ),
    );
  }
}