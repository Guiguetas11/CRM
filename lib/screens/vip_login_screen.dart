import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/sheets_service.dart';
import './loginscreen.dart';
import '../services/shared_prefs.dart';
import 'package:universal_html/html.dart' as html;
import 'home_screen.dart';

class LoginVipScreen extends StatefulWidget {
  static const String id = '/vip';
  final SheetsService sheetsService;

  const LoginVipScreen({super.key, required this.sheetsService});

  @override
  State<LoginVipScreen> createState() => _LoginVipScreenState();
}

class _LoginVipScreenState extends State<LoginVipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscureText = true;
  bool _stayLoggedIn = false; // Novo estado para a checkbox

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Proteger contra currentState null
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1) Autentica credenciais
      final userFound = await widget.sheetsService.verificarLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (userFound.isEmpty) {
        setState(() {
          _errorMessage = 'Email ou senha incorretos';
          _isLoading = false;
        });
        return;
      }
      if (_stayLoggedIn) {
        await AppPreferences.saveLoginState(
          _emailController.text.trim(),
          true, // isVip = true
        );
      }
      // 2) Valida status
      final resultado = await widget.sheetsService.validarStatusUsuario(
        _emailController.text.trim(),
      );
      if (!resultado['valido']) {
        setState(() {
          _errorMessage = resultado['mensagem'];
          _isLoading = false;
        });
        return;
      }

      // 3) Registra acesso
      await widget.sheetsService.registrarAcesso(_emailController.text.trim());

      // 4) Guarda linha do usuário (incluindo campo vip)
      final Map<String, String> usuarioRow =
          Map<String, String>.from(resultado['usuario'] as Map);
      AppState.instance.vipUserRow = usuarioRow;

      // 5) Se a checkbox "Permanecer conectado" estiver marcada
      if (_stayLoggedIn) {
        // Armazenar email (ou token) no localStorage
        html.window.localStorage['user_email'] = _emailController.text.trim();
      }

      // Navega para a home
      if (mounted) {
        Navigator.pushReplacementNamed(context, HomeScreen.id);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao conectar com o servidor: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = LoginScreen.primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo circular
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Os melhores palpites, você encontra aqui!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Insira seu email' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campo Senha
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: const TextStyle(color: Colors.white),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Insira sua senha' : null,
                  ),

                  // Checkbox: "Permanecer conectado"
                  Row(
                    children: [
                      Checkbox(
                        value: _stayLoggedIn,
                        onChanged: (value) {
                          setState(() {
                            _stayLoggedIn = value!;
                          });
                        },
                      ),
                      const Text(
                        'Permanecer conectado',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Botão Entrar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        foregroundColor: Colors.black,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('ENTRAR',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Separador "Ou"
                  Row(
                    children: const [
                      Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('Ou'),
                      ),
                      Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Botão: Acesso Gratuito
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Volta para a tela anterior
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor:
                            const Color.fromRGBO(255, 255, 255, 1),
                        side: const BorderSide(
                            color: Color.fromARGB(136, 224, 224, 224)),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Text(
                        'Acesso Gratuito',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
