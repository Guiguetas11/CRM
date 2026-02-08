// models/channel.dart
class Channel {
  final String name;
  final String logoUrl;
  // A URL do embed (pode ser um link direto do player ou uma página com o player)
  final String embedUrl; 

  const Channel({
    required this.name,
    required this.logoUrl,
    required this.embedUrl,
  });
}

// Lista de canais de exemplo para simular seu site
const List<Channel> mockChannels = [
  Channel(
    name: 'Canal News',
    logoUrl: 'https://via.placeholder.com/150/0000FF/808080?text=NEWS',
    embedUrl: 'http://gumid23.xvdlrpeamztgqnsuhowjybicfmekahrqtdvzpkmn.icu:80/155846650/817126985/4230935', // Substitua pelo URL real do embed
  ),
  Channel(
    name: 'Filmes 24h',
    logoUrl: 'https://via.placeholder.com/150/FF0000/FFFFFF?text=MOVIE',
    embedUrl: '<iframe src="https://rdcanais.top/ae" allow="encrypted-media" allowfullscreen="" frameborder="0" width="100%" height="400"></iframe>', // Substitua pelo URL real do embed
  ),
  Channel(
    name: 'Esportes Premium',
    logoUrl: 'https://via.placeholder.com/150/00FF00/000000?text=SPORT',
    embedUrl: 'https://example.com/embed/sport-player', // Substitua pelo URL real do embed
  ),
  Channel(
    name: 'Desenhos Kids',
    logoUrl: 'https://via.placeholder.com/150/FFFF00/000000?text=KIDS',
    embedUrl: 'https://rdcanais.top/ae', // Substitua pelo URL real do embed
  ),
];