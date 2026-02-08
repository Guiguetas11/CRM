// import 'package:flutter/material.dart'; REMOVIDO

// --- Constantes e Estrutura de Dados ---
const String localStorageKey = 'channels_config_json';
const String viewType = 'channel-iframe-view'; // Usado no IframePlayerRoute

// JSON inicial agora usa o campo "url" completo em vez de "slug"
const String initialJson = '''
[
  {"name": "A Fazenda 17 - Sinal 1", "url": "https://rdcanais.top/fazenda17"},
  {"name": "A Fazenda 17 - Sinal 2", "url": "https://rdcanais.top/fazenda17-2"},
  {"name": "A Fazenda 17 - Sinal 3", "url": "https://rdcanais.top/fazenda17-3"},
  {"name": "A Fazenda 17 - Sinal 4", "url": "https://rdcanais.top/fazenda17-4"},
  {"name": "A Fazenda 17 - Sinal 5", "url": "https://rdcanais.top/fazenda17-5"},
  {"name": "A Fazenda 17 - Sinal 6", "url": "https://rdcanais.top/fazenda17-6"},
  {"name": "Band", "url": "https://rdcanais.top/band"},
  {"name": "Record", "url": "https://rdcanais.top/record"},
  {"name": "RedeTV", "url": "https://rdcanais.top/redetv"},
  {"name": "SBT", "url": "https://rdcanais.top/sbt"},
  {"name": "TV Brasil", "url": "https://rdcanais.top/tvbrasil"},
  {"name": "TV Cultura", "url": "https://rdcanais.top/tvcultura"},
  {"name": "Cartoon Network", "url": "https://rdcanais.top/cartoonnetwork"},
  {"name": "Comedy Central", "url": "https://rdcanais.top/comedycentral"},
  {"name": "Cinemax", "url": "https://rdcanais.top/cinemax"},
  {"name": "Cartoonito", "url": "https://rdcanais.top/cartoonito"},
  {"name": "Discovery Kids", "url": "https://rdcanais.top/discoverykids"},
  {"name": "Discovery Science", "url": "https://rdcanais.top/discoveryscience"},
  {"name": "Discovery Theater", "url": "https://rdcanais.top/discoverytheater"},
  {"name": "Discovery World", "url": "https://rdcanais.top/discoveryworld"},
  {"name": "E", "url": "https://rdcanais.top/e"},
  {"name": "Futura", "url": "https://rdcanais.top/futura"},
  {"name": "Globo Play Novelas", "url": "https://rdcanais.top/globoplaynovelas"},
  {"name": "Gloob", "url": "https://rdcanais.top/gloob"},
  {"name": "Gloobinho", "url": "https://rdcanais.top/gloobinho"},
  {"name": "GNT", "url": "https://rdcanais.top/gnt"},
  {"name": "HBO", "url": "https://rdcanais.top/hbo"},
  {"name": "HBO 2", "url": "https://rdcanais.top/hbo2"},
  {"name": "HBO Family", "url": "https://rdcanais.top/hbofamily"},
  {"name": "HBO Plus", "url": "https://rdcanais.top/hboplus"},
  {"name": "HBO Signature", "url": "https://rdcanais.top/hbosignature"},
  {"name": "HBO Xtreme", "url": "https://rdcanais.top/hboxtreme"},
  {"name": "History", "url": "https://rdcanais.top/history"},
  {"name": "History 2", "url": "https://rdcanais.top/history2"},
  {"name": "Megapix", "url": "https://rdcanais.top/megapix"},
  {"name": "Multishow", "url": "https://rdcanais.top/multishow"},
  {"name": "MTV Live", "url": "https://rdcanais.top/mtvlive"},
  {"name": "Nick Jr", "url": "https://rdcanais.top/nickjr"},
  {"name": "Nickelodeon", "url": "https://rdcanais.top/nickelodeon"},
  {"name": "Paramount Network", "url": "https://rdcanais.top/paramountnetwork"},
  {"name": "Space", "url": "https://rdcanais.top/space"},
  {"name": "Studio Universal", "url": "https://rdcanais.top/studiouniversal"},
  {"name": "Telecine Action", "url": "https://rdcanais.top/telecineaction"},
  {"name": "Telecine Premium", "url": "https://rdcanais.top/telecinepremium"},
  {"name": "Telecine Touch", "url": "https://rdcanais.top/telecinetouch"},
  {"name": "TLC", "url": "https://rdcanais.top/tlc"},
  {"name": "TNT", "url": "https://rdcanais.top/tnt"},
  {"name": "TNT Novelas", "url": "https://rdcanais.top/tntnovelas"},
  {"name": "TNT Series", "url": "https://rdcanais.top/tntseries"},
  {"name": "Universal Premiere", "url": "https://rdcanais.top/universalpremiere"},
  {"name": "Universal Reality", "url": "https://rdcanais.top/universalreality"},
  {"name": "Universal TV", "url": "https://rdcanais.top/universaltv"},
  {"name": "USA", "url": "https://rdcanais.top/usa"},
  {"name": "Warner TV", "url": "https://rdcanais.top/warnertv"},
  {"name": "Band Sports", "url": "https://rdcanais.top/bandsports"},
  {"name": "Caze TV", "url": "https://rdcanais.top/cazetv"},
  {"name": "Caze TV 2", "url": "https://rdcanais.top/cazetv2"},
  {"name": "Caze TV 3", "url": "https://rdcanais.top/cazetv3"},
  {"name": "Combate", "url": "https://rdcanais.top/combate"},
  {"name": "UFC Fight Pass", "url": "https://rdcanais.top/ufcfightpass"},
  {"name": "Discovery Turbo", "url": "https://rdcanais.top/discoveryturbo"},
  {"name": "ESPN", "url": "https://rdcanais.top/espn"},
  {"name": "ESPN 2", "url": "https://rdcanais.top/espn2"},
  {"name": "ESPN 3", "url": "https://rdcanais.top/espn3"},
  {"name": "ESPN 4", "url": "https://rdcanais.top/espn4"},
  {"name": "ESPN 5", "url": "https://rdcanais.top/espn5"},
  {"name": "ESPN 6", "url": "https://rdcanais.top/espn6"},
  {"name": "Max (Esportes)", "url": "https://rdcanais.top/max"},
  {"name": "Max 2 (Esportes)", "url": "https://rdcanais.top/max2"},
  {"name": "Max 3 (Esportes)", "url": "https://rdcanais.top/max3"},
  {"name": "Paramount Plus (Esportes)", "url": "https://rdcanais.top/paramountplus"},
  {"name": "Paramount Plus 2 (Esportes)", "url": "https://rdcanais.top/paramountplus2"},
  {"name": "Paramount Plus 3 (Esportes)", "url": "https://rdcanais.top/paramountplus3"},
  {"name": "Premiere Clubes", "url": "https://rdcanais.top/premiereclubes"},
  {"name": "Premiere Clubes Alternativo", "url": "https://rdcanais.top/premiereclubesalternativo"},
  {"name": "Premiere 2", "url": "https://rdcanais.top/premiere2"},
  {"name": "Premiere 2 Alternativo", "url": "https://rdcanais.top/premiere2alternativo"},
  {"name": "Premiere 3", "url": "https://rdcanais.top/premiere3"},
  {"name": "Premiere 3 Alternativo", "url": "https://rdcanais.top/premiere3alternativo"},
  {"name": "Premiere 4", "url": "https://rdcanais.top/premiere4"},
  {"name": "Premiere 4 Alternativo", "url": "https://rdcanais.top/premiere4alternativo"},
  {"name": "Premiere 5", "url": "https://rdcanais.top/premiere5"},
  {"name": "Premiere 5 Alternativo", "url": "https://rdcanais.top/premiere5alternativo"},
  {"name": "Premiere 6", "url": "https://rdcanais.top/premiere6"},
  {"name": "Premiere 6 Alternativo", "url": "https://rdcanais.top/premiere6alternativo"},
  {"name": "Premiere 7", "url": "https://rdcanais.top/premiere7"},
  {"name": "Premiere 7 Alternativo", "url": "https://rdcanais.top/premiere7alternativo"},
  {"name": "Premiere 8", "url": "https://rdcanais.top/premiere8"},
  {"name": "Premiere 8 Alternativo", "url": "https://rdcanais.top/premiere8alternativo"},
  {"name": "Prime Video 1 (Esportes)", "url": "https://rdcanais.top/primevideo"},
  {"name": "Prime Video 2 (Esportes)", "url": "https://rdcanais.top/primevideo2"},
  {"name": "Prime Video 3 (Esportes)", "url": "https://rdcanais.top/primevideo3"},
  {"name": "Prime Video 4 (Esportes)", "url": "https://rdcanais.top/primevideo4"},
  {"name": "SporTV 1", "url": "https://rdcanais.top/sportv"},
  {"name": "SporTV Alternativo", "url": "https://rdcanais.top/sportvalternativo"},
  {"name": "SporTV 2", "url": "https://rdcanais.top/sportv2"},
  {"name": "SporTV 2 Alternativo", "url": "https://rdcanais.top/sportv2alternativo"},
  {"name": "SporTV 3", "url": "https://rdcanais.top/sportv3"},
  {"name": "SporTV 3 Alternativo", "url": "https://rdcanais.top/sportv3alternativo"},
  {"name": "SporTV 4", "url": "https://rdcanais.top/sportv4"},
  {"name": "SporTV 4 Alternativo", "url": "https://rdcanais.top/sportv4alternativo"},
  {"name": "Globo BA", "url": "https://rdcanais.top/globoba"},
  {"name": "Globo DF", "url": "https://rdcanais.top/globodf"},
  {"name": "Globo RJ", "url": "https://rdcanais.top/globorj"},
  {"name": "Globo SP", "url": "https://rdcanais.top/globosp"}
]
''';

class Channel {
  final String name;
  final String url; // Alterado de 'slug' para 'url'
  // O código do ícone e o getter 'icon' foram removidos.

  Channel({
    required this.name,
    required this.url, // Alterado de 'slug' para 'url'
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] as String,
      url: json['url'] as String, // Alterado de 'slug' para 'url'
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url, // Alterado de 'slug' para 'url'
    };
  }
}