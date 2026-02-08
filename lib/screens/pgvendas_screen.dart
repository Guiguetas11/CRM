import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VipPaymentScreen extends StatelessWidget {
  static const String id = '/vip-payment';

  final Color primaryColor = const Color.fromARGB(255, 108, 9, 229);

  final List<_PlanoData> planos = const [
    _PlanoData(
      title: 'Mensal',
      price: 'R\$ 65,00/mês',
      benefits: [
        'Acesso completo a filmes e séries',
        'Suporte 24/7',
      ],
      tipo: 'mensal',
    ),
    _PlanoData(
      title: 'Trimestral',
      price: 'R\$ 150,00/trimestre',
      benefits: [
        'Tudo do plano mensal',
        '5 dias adicionais após vencimento',
      ],
      tipo: 'trimestral',
    ),
    _PlanoData(
      title: 'Anual',
      price: 'R\$ 680,00/ano',
      benefits: [
        'Tudo do trimestral',
        'Brinde: 30 dias extras após vencimento',
      ],
      tipo: 'anual',
    ),
  ];

  final List<_PlanoData> categorias = const [
    _PlanoData(
      title: 'Filmes',
      price: 'R\$ 30,00/mês',
      benefits: ['Acesso aos Filmes'],
      tipo: 'filme',
    ),
    _PlanoData(
      title: 'Séries',
      price: 'R\$ 30,00/mês',
      benefits: ['Acesso as Séries'],
      tipo: 'serie',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Libere o acesso do VibeCine'),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 1 : 2;
        final aspectRatio = constraints.maxWidth < 600 ? 1.1 : 1.3;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              children: [
                _buildBanner(primaryColor),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Planos VibeCine',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildGrid(planos, context, crossCount, aspectRatio, primaryColor),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Assinar por Categoria',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildGrid(categorias, context, crossCount, aspectRatio, primaryColor),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBanner(Color primaryColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withOpacity(0.8), width: 3),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Assinatura VIP – Acesso Total ao App',
            style: TextStyle(
              color: primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Assista aos melhores filmes e séries, onde quiser, quando quiser.',
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildGrid(List<_PlanoData> items, BuildContext context, int cross, double ratio, Color primaryColor) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: ratio,
      ),
      itemBuilder: (ctx, i) {
        final p = items[i];
        return _PlanoCard(
          title: p.title,
          price: p.price,
          benefits: p.benefits,
          onPressed: () => _goToPayment(context, p.tipo),
          primaryColor: primaryColor,
        );
      },
    );
  }

  void _goToPayment(BuildContext context, String tipo) async {
    final url = buildCheckoutLink(tipo);
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a página de pagamento.')),
      );
    }
  }

  String buildCheckoutLink(String tipo) {
    switch (tipo) {
      case 'mensal':
        return 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=2c938084981e9ee401982e778df4055f';
      case 'trimestral':
        return 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=2c938084981e9ee401982e786e870560';
      case 'anual':
        return 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=2c938084981e9ee501982e78bb45051e';
      case 'filme':
        return 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=2c938084981e9ee50198301c944d05e8';
      case 'serie':
        return 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=2c938084983019900198301d38320030';
      default:
        throw ArgumentError('Tipo de assinatura inválido: $tipo');
    }
  }
}

class _PlanoCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> benefits;
  final VoidCallback onPressed;
  final Color primaryColor;

  const _PlanoCard({
    required this.title,
    required this.price,
    required this.benefits,
    required this.onPressed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      shadowColor: primaryColor.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: benefits
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  shadowColor: primaryColor.withOpacity(0.9),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                onPressed: onPressed,
                child: const Text('ASSINAR AGORA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanoData {
  final String title;
  final String price;
  final List<String> benefits;
  final String tipo;

  const _PlanoData({
    required this.title,
    required this.price,
    required this.benefits,
    required this.tipo,
  });
}
