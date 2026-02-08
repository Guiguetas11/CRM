// screens/live_tv_test_screen.dart
import 'package:flutter/material.dart';
import 'channel.dart'; // Importa o modelo e a lista
import 'channel_player.dart'; // Importa a tela do player

class LiveTvTestScreen extends StatelessWidget {
  static const Color primaryColor = Color.fromARGB(255, 108, 9, 229);

  const LiveTvTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Canais ao Vivo (Teste)'),
        backgroundColor: primaryColor,
        elevation: 6,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        // Layout 2 colunas para dispositivos móveis
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9, // Ajuste para melhor visualização do card
        ),
        itemCount: mockChannels.length,
        itemBuilder: (context, index) {
          final channel = mockChannels[index];
          return _buildChannelCard(context, channel);
        },
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel channel) {
    return InkWell(
      onTap: () {
        // Navega para a tela do player ao clicar
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelPlayerScreen(
              channelName: channel.name,
              embedUrl: channel.embedUrl,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagem (Logo) do Canal
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                channel.logoUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 100, height: 100,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.live_tv,
                  size: 80,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Nome do Canal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                channel.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}