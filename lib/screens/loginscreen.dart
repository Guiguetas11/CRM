import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import '../services/sheets_services.dart'; // ajuste o caminho conforme seu projeto
import '../services/shared_prefs.dart'; // import da classe AppPreferences

class LoginScreen extends StatefulWidget {
  static const String id = '/login';
  // Cor padrão do app, substituindo o vermelho.
  static const Color primaryColor = Color.fromARGB(255, 108, 9, 229);

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class LoadingTypingText extends StatefulWidget {
  const LoadingTypingText({super.key});

  @override
  State<LoadingTypingText> createState() => _LoadingTypingTextState();
}

class _LoadingTypingTextState extends State<LoadingTypingText> {
  final List<String> frases = [
    'Atualizando...',
  ];

  int indexFrase = 0;
  int indexLetra = 0;
  String exibido = '';
  late Timer timer;

  @override
  void initState() {
    super.initState();
    iniciarAnimacao();
  }

  void iniciarAnimacao() {
    timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final fraseAtual = frases[indexFrase];

      if (indexLetra < fraseAtual.length) {
        setState(() => exibido = fraseAtual.substring(0, indexLetra + 1));
        indexLetra++;
        return;
      }

    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      exibido,
      style: const TextStyle(color: Colors.white70),
    );
  }
}


class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _stayLoggedIn = false;
  
  bool _isServiceInitialized = false; // Novo: Estado da inicialização do serviço
  late SheetsServices _sheetsService;

  @override
  void initState() {
    super.initState();
    _initSheetsAndAutoLogin(); // Chama a nova função combinada
  }

  Future<void> _initSheetsAndAutoLogin() async {
    try {
      _sheetsService = await SheetsServices.create();
      if (mounted) {
        setState(() {
          _isServiceInitialized = true;
        });
        await _autoLogin();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao inicializar serviço de autenticação. Tente novamente mais tarde.';
          _isServiceInitialized = true; // Permite a exibição da mensagem de erro
        });
      }
    }
  }

  Future<void> _autoLogin() async {
    // Só tenta o auto-login se a inicialização do serviço foi bem-sucedida
    if (!_isServiceInitialized || _errorMessage != null) return;

    final loginState = await AppPreferences.getLoginState();
    final email = loginState['email'] as String?;
    final isVip = loginState['is_vip'] as bool? ?? false;

    if (email != null && isVip) {
      if (mounted) {
        // mantém compatibilidade com sua rota: HomeScreen tentará ler o email do SharedPreferences
        Navigator.pushReplacementNamed(context, HomeScreen.id);
      }
    }
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Novo: Verifica se o serviço de Sheets está pronto antes de continuar
    if (!_isServiceInitialized) {
       setState(() => _errorMessage = 'Serviço de autenticação não inicializado.');
       return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final authenticated = await _sheetsService.authenticateVip(
        email: email,
        password: password,
      );

      if (authenticated) {
        // salva estado de login (se desejado) via AppPreferences — seu wrapper existente
        if (_stayLoggedIn) {
          await AppPreferences.saveLoginState(email, true);
        } else {
          await AppPreferences.clearLoginState();
        }

        // SALVA O EMAIL NOS SharedPreferences para que HomeScreen possa recuperar e buscar o nome no Sheets
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userEmail', email);
        } catch (_) {
          // falha ao salvar SharedPreferences não bloqueia o fluxo
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, HomeScreen.id);
        }
      } else {
        setState(() {
          _errorMessage = 'Email ou senha incorretos.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao autenticar. Verifique sua conexão ou tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  

  @override
  Widget build(BuildContext context) {
    // Variável para determinar a largura máxima do formulário
    final screenWidth = MediaQuery.of(context).size.width;
    const double maxFormWidth = 450.0;
    
    // Calcula a largura que o formulário deve ter (largura total ou máxima de 450)
    final formWidth = screenWidth > maxFormWidth ? maxFormWidth : screenWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
            // Usa SizedBox para limitar a largura do conteúdo em telas grandes (RESPONSIVIDADE)
            child: SizedBox( 
              width: formWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    'Bem-vindo ao VibeCine',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assista aos melhores filmes e séries, onde quiser, quando quiser.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // NOVO: Indicador de carregamento/erro de inicialização
                  if (!_isServiceInitialized)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: LoginScreen.primaryColor),
                            SizedBox(height: 10),
                              LoadingTypingText(),//animação do texto 
                          ],
                        ),
                      ),
                    )
                  else // ENVOLVE O FORM COM 'ELSE'
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              focusedBorder: OutlineInputBorder(
                                // COR PADRÃO (ROXO)
                                borderSide: BorderSide(color: LoginScreen.primaryColor), 
                                borderRadius: BorderRadius.circular(6),
                              ),
                              filled: true,
                              fillColor: Colors.grey[900],
                              prefixIcon: const Icon(Icons.email, color: Colors.grey),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe seu email';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                return 'Email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(color: Colors.white),
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              focusedBorder: OutlineInputBorder(
                                // COR PADRÃO (ROXO)
                                borderSide: BorderSide(color: LoginScreen.primaryColor),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              filled: true,
                              fillColor: Colors.grey[900],
                              prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe sua senha';
                              }
                              if (value.length < 6) {
                                return 'Senha deve ter ao menos 6 caracteres';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Checkbox(
                                value: _stayLoggedIn,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _stayLoggedIn = value ?? false;
                                  });
                                },
                                // Personaliza a cor do checkbox (opcional, mas recomendado)
                                activeColor: LoginScreen.primaryColor, 
                                checkColor: Colors.white,
                              ),
                              const Text(
                                'Permanecer conectado',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              // Desabilita se estiver carregando OU se o serviço não estiver inicializado com sucesso
                              onPressed: _isLoading || !_isServiceInitialized ? null : _login, 
                              style: ElevatedButton.styleFrom(
                                // COR PADRÃO (ROXO)
                                backgroundColor: LoginScreen.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('ACESSAR'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/vip-payment');
                    },
                    child: const Text(
                      'Ainda não é VIP? Torne-se VIP agora',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    '© 2025 VibeCine. Todos os direitos reservados.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}