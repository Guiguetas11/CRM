import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Para usar o logger

class SheetsService {

  // Planilha de gerenciamento de login VIP
  static const _spreadsheetIdVip = '1BZRljnzFiTZJAXPudq5UT9Np0omIMeO43JjV8jOh6kk'; // id de email, senhas e acesso vip.


  
  final GSheets _gsheets;

  /// Construtor privado usado internamente e para testes
  SheetsService._(this._gsheets);

  /// Construtor público de fábrica para uso normal
  /// Carrega credenciais do asset e inicializa o GSheets
  static Future<SheetsService> create() async {
    final credentials = await rootBundle.loadString('assets/credentials.json');
    final gsheets = GSheets(json.decode(credentials));
    return SheetsService._(gsheets);
  }

  /// Construtor público para fornecer um GSheets já instanciado (ideal para testes)
  SheetsService.test(GSheets gsheets) : _gsheets = gsheets;

 
  /// Busca todas as linhas da aba cujo nome é [sheetTitle] na planilha de usuários VIP
  Future<List<Map<String, String>>> fetchVipUsers(String sheetTitle) async {
    final ss = await _gsheets.spreadsheet(_spreadsheetIdVip);
    final sheet = ss.worksheetByTitle(sheetTitle);
    if (sheet == null) return [];

    final allRows = await sheet.values.allRows();
    if (allRows.isEmpty) return [];

    final headers = allRows.first;
    final dataRows = allRows.skip(1);

    return dataRows.map((row) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = (i < row.length) ? row[i] : '';
      }
      return map;
    }).toList();
  }
  
  /// Verifica as credenciais do usuário na planilha VIP
  Future<Map<String, String>> verificarLogin(String login, String senha) async {
    final usuarios = await fetchVipUsers('login_vip'); // Nome da aba com os dados de usuários
    
    // Procurar por credenciais correspondentes
    try {
      final userFound = usuarios.firstWhere(
        (row) => 
          row['login'] == login && 
          row['senha'] == senha,
        orElse: () => {},
      );
      
      return userFound;
    } catch (e) {
      debugPrint('Erro ao verificar credenciais: $e');
      return {};
    }
  }

  /// Verifica se o usuário está ativo e com assinatura válida
  Future<Map<String, dynamic>> validarStatusUsuario(String login) async {
    final usuarios = await fetchVipUsers('login_vip');
    
    try {
      final userFound = usuarios.firstWhere(
        (row) => row['login'] == login,
        orElse: () => {},
      );
      
      if (userFound.isEmpty) {
        return {
          'valido': false,
          'mensagem': 'Usuário não encontrado'
        };
      }
      
      // Verificar status
      final status = userFound['status']?.toLowerCase() ?? '';
      if (status != 'ativo') {
        return {
          'valido': false,
          'mensagem': 'Sua conta está inativa. Por favor, renove sua assinatura.'
        };
      }
      
      // Verificar validade (se existir)
      final validade = userFound['validade'] ?? '';
      if (validade.isNotEmpty) {
        try {
          // Usar o DateFormat para parse padronizado
          final validadeDate = DateFormat('dd/MM/yyyy').parse(validade);
          final hoje = DateTime.now();
          
          if (hoje.isAfter(validadeDate)) {
            return {
              'valido': false,
              'mensagem': 'Sua assinatura expirou em $validade. Por favor, entre em contato com administrador.'
            };
          }
        } catch (e) {
          debugPrint('Erro ao processar data de validade: $e');
          // Continuar mesmo com erro no formato da data
        }
      }
      
      // Se chegou até aqui, usuário está válido
      return {
        'valido': true,
        'usuario': userFound
      };
    } catch (e) {
      debugPrint('Erro ao validar status: $e');
      return {
        'valido': false,
        'mensagem': 'Erro ao validar usuário: $e'
      };
    }
  }
  
  /// Atualiza o último acesso do usuário
  Future<bool> registrarAcesso(String login) async {
    try {
      final ss = await _gsheets.spreadsheet(_spreadsheetIdVip);
      final sheet = ss.worksheetByTitle('login_vip');
      if (sheet == null) return false;
      
      // Buscar todas as linhas para encontrar o usuário
      final allRows = await sheet.values.allRows();
      if (allRows.isEmpty) return false;
      
      final headers = allRows.first;
      final loginIndex = headers.indexOf('login');
      final ultimoAcessoIndex = headers.indexOf('ultimo_acesso');
      
      if (loginIndex == -1) return false;
      
      // Encontrar a linha do usuário
      int userRowIndex = -1;
      for (int i = 1; i < allRows.length; i++) {
        if (allRows[i].length > loginIndex && allRows[i][loginIndex] == login) {
          userRowIndex = i + 1; // +1 porque a indexação do GSheets começa em 1
          break;
        }
      }
      
      if (userRowIndex == -1) return false;
      
      // Registrar data e hora do acesso
      final agora = DateTime.now();
      final dataFormatada = '${agora.day}/${agora.month}/${agora.year} ${agora.hour}:${agora.minute}';
      
      // Se tiver coluna de último acesso, atualizar
      if (ultimoAcessoIndex != -1) {
        await sheet.values.insertValue(
          dataFormatada, 
          column: ultimoAcessoIndex + 1, // +1 porque a indexação do GSheets começa em 1
          row: userRowIndex
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('Erro ao registrar acesso: $e');
      return false;
    }
  }

  /// Acessa as informações da planilha do NBA








}