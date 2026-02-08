// ts_player_web.dart
// SUBSTITUA seu arquivo web por este.
// Este arquivo é importado apenas em builds web via import condicional.

import 'dart:html' as html;
// Import para platformViewRegistry sem warning
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../models/content_model.dart';

class TSPlayerImpl extends StatefulWidget {
  final M3UContent content;
  const TSPlayerImpl({Key? key, required this.content}) : super(key: key);

  @override
  State<TSPlayerImpl> createState() => _TSPlayerImplState();
}

class _TSPlayerImplState extends State<TSPlayerImpl> {
  late final String viewTypeId;

  @override
  void initState() {
    super.initState();

    viewTypeId = 'hls_video_${widget.content.id}';

    // usa o registry vindo de dart:ui_web (evita deprecation warning)
    ui_web.platformViewRegistry.registerViewFactory(viewTypeId, (int _) {
      final container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..style.position = 'relative';

      final titleDiv = html.DivElement()
        ..text = widget.content.title
        ..style.position = 'absolute'
        ..style.top = '8px'
        ..style.left = '8px'
        ..style.color = 'white'
        ..style.fontSize = '18px'
        ..style.fontWeight = 'bold'
        ..style.zIndex = '10'
        ..style.textShadow = '2px 2px 4px black';
      container.append(titleDiv);

      final fullscreenBtn = html.ButtonElement()
        ..text = 'Tela Cheia'
        ..style.position = 'absolute'
        ..style.top = '8px'
        ..style.right = '8px'
        ..style.zIndex = '10'
        ..style.padding = '6px 12px'
        ..style.backgroundColor = 'rgba(255,255,255,0.12)'
        ..style.color = 'white'
        ..style.border = 'none'
        ..style.borderRadius = '4px'
        ..style.cursor = 'pointer';
      fullscreenBtn.onClick.listen((_) {
        final videoEl = container.querySelector('video');
        if (videoEl != null) {
          try {
            // requestFullscreen pode lançar
            videoEl.requestFullscreen();
          } catch (e) {}
        }
      });
      container.append(fullscreenBtn);

      final statusDiv = html.DivElement()
        ..id = 'status_${widget.content.id}'
        ..style.position = 'absolute'
        ..style.bottom = '8px'
        ..style.left = '8px'
        ..style.color = 'white'
        ..style.zIndex = '10'
        ..style.fontSize = '13px'
        ..style.textShadow = '1px 1px 2px black';
      container.append(statusDiv);

      final video = html.VideoElement()
        ..id = 'video_${widget.content.id}'
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      container.append(video);

      final url = widget.content.url.trim();

      void setStatus(String text) {
        statusDiv.text = text;
        // também manda pro console pra debug
        html.window.console.log('[TSPlayer] $text');
      }

      if (url.isEmpty) {
        setStatus('URL vazia');
        return container;
      }

      final lower = url.toLowerCase();
      final isHls = lower.contains('.m3u8');
      final isTs = lower.endsWith('.ts');

      if (isHls) {
        // HLS.js path (igual antes)
        final script = html.ScriptElement()
          ..src = 'https://cdn.jsdelivr.net/npm/hls.js@latest'
          ..type = 'application/javascript';

        script.onError.listen((_) {
          setStatus('Erro ao carregar HLS.js — fallback nativo.');
          video.src = url;
        });

        script.onLoad.listen((_) {
          setStatus('HLS.js carregado — iniciando stream...');
          try {
            final jsInit = """
              (function() {
                try {
                  if (window.Hls && Hls.isSupported()) {
                    var video = document.getElementById('video_${widget.content.id}');
                    var hls = new Hls();
                    hls.loadSource('${url.replaceAll("'", "\\'")}');
                    hls.attachMedia(video);
                    hls.on(Hls.Events.MANIFEST_PARSED, function() { video.play().catch(function(e){}); });
                    hls.on(Hls.Events.ERROR, function(event, data) {
                      var st = document.getElementById('status_${widget.content.id}');
                      if(st) st.textContent = 'Erro HLS: ' + data.type + ' - ' + (data.details || '');
                    });
                  } else {
                    var vid = document.getElementById('video_${widget.content.id}');
                    if(vid) vid.src = '${url.replaceAll("'", "\\'")}';
                  }
                } catch(e) {
                  var st = document.getElementById('status_${widget.content.id}');
                  if(st) st.textContent = 'Init HLS falhou: ' + e;
                }
              })();
            """;
            final initScript = html.ScriptElement()..text = jsInit;
            container.append(initScript);
          } catch (e) {
            setStatus('Falha ao inicializar HLS: $e');
            video.src = url;
          }
        });

        container.append(script);
      } else if (isTs) {
        // Estratégia para .ts: tentativa + diagnóstico
        setStatus('Arquivo .ts detectado — verificando suporte do navegador...');

        try {
          // checa canPlayType para video/mp2t
          final canPlay = video.canPlayType('video/mp2t');
          if (canPlay == '') {
            // tenta fallback para mp4 codec check (pode ou não ajudar)
            final fb = video.canPlayType('video/mp4; codecs="avc1.42E01E, mp4a.40.2"');
            if (fb == '') {
              // Tenta um HEAD para obter Content-Type (só funciona se CORS permitir)
              html.HttpRequest.request(url, method: 'HEAD').then((resp) {
                final ct = resp.getResponseHeader('content-type') ?? 'desconhecido';
                setStatus('.ts não suportado nativamente no navegador. Content-Type: $ct. Recomendo fornecer .m3u8 (HLS) ou MP4, ou usar o app móvel.');
              }).catchError((err) {
                // se falhar, normalmente é CORS ou servidor bloqueando
                setStatus('.ts provavelmente não suportado no navegador OU requisição HEAD bloqueada (CORS). Tente .m3u8 ou MP4, ou reproduza no app móvel.');
              });
            } else {
              setStatus('Tentando reproduzir .ts via fallback (verifique se toca).');
              video.src = url;
            }
          } else {
            setStatus('Reproduzindo .ts (declared: $canPlay).');
            video.src = url;
          }

          // sempre registra onError pra exibir erro mais legível
          video.onError.listen((ev) {
            // tenta extrair info do elemento de vídeo
            try {
              final err = (video as dynamic).error;
              if (err != null) {
                setStatus('Erro ao carregar .ts — código: ${err.code ?? 'n/a'}; message: ${err.message ?? ''}. Provável problema de codec/CORS.');
              } else {
                setStatus('Erro ao carregar .ts: verifique URL, CORS ou codec. Use .m3u8/MP4 ou abra no app móvel.');
              }
            } catch (_) {
              setStatus('Erro ao carregar .ts: verifique URL, CORS ou codec. Use .m3u8/MP4 ou abra no app móvel.');
            }
          });
        } catch (e) {
          setStatus('Erro ao processar .ts: $e');
          video.src = url;
        }
      } else {
        // outros formatos (mp4, webm, ogg) — mesma lógica de antes
        try {
          String mime = 'video/mp4';
          if (lower.endsWith('.webm')) mime = 'video/webm';
          if (lower.endsWith('.ogv') || lower.endsWith('.ogg')) mime = 'video/ogg';

          final canPlay = video.canPlayType(mime);
          if (canPlay == '') {
            setStatus('Formato possivelmente não suportado nativamente: $mime');
          } else {
            setStatus('Reproduzindo: $mime');
          }
        } catch (_) {}
        video.src = url;
        video.onError.listen((ev) {
          setStatus('Erro ao carregar vídeo: verifique a URL/codec. (Se for CORS, veja o console).');
        });
      }

      return container;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.content.title),
        backgroundColor: const Color.fromARGB(255, 108, 9, 229),
      ),
      body: HtmlElementView(viewType: viewTypeId),
    );
  }
}
