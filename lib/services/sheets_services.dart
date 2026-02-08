import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart'; 
import 'package:gsheets/gsheets.dart';

class SheetsServices {
  // ATENÇÃO: Substitua pelo seu ID da Planilha. O ID fornecido é um exemplo.
  static const _spreadsheetId = '1FES3MkkPe3zxURCD7U0Fpnh8pIGe-HeI1jB251-KDLw';
  static const _vipSheetName = 'login_vip';
  static const _channelsSheetName = 'canais_tv';

  final Spreadsheet _spreadsheet;

  SheetsServices._(this._spreadsheet);

  static Future<SheetsServices> create() async {
    // Carrega o arquivo JSON com suas credenciais do serviço
    final credentials = await rootBundle.loadString('assets/credentials.json');
    final gsheets = GSheets(json.decode(credentials));
    final spreadsheet = await gsheets.spreadsheet(_spreadsheetId);
    return SheetsServices._(spreadsheet);
  }

  // --- MÉTODOS VIP (Mantidos) ---
  Future<bool> authenticateVip({required String email, required String password}) async {
    final sheet = _spreadsheet.worksheetByTitle(_vipSheetName);
    if (sheet == null) return false;
    final rows = await sheet.values.allRows();
    for (final row in rows.skip(1)) {
      if (row.length >= 2 && row[0] == email && row[1] == password) return true;
    }
    return false;
  }

  Future<String?> getNameByEmail(String email) async {
    final sheet = _spreadsheet.worksheetByTitle(_vipSheetName);
    if (sheet == null) return null;
    final rows = await sheet.values.allRows();
    if (rows.isEmpty) return null;

    // Lógica simples de busca
    for (final row in rows.skip(1)) {
      if (row.isNotEmpty && row[0] == email) {
        return row.length > 2 ? row[2] : null; // Assume nome na coluna 2
      }
    }
    return null;
  }

  // --- MÉTODOS DE CANAIS (Resolvem o erro do iframerplayer.dart) ---
  
  /// Obtém todos os canais da planilha 'canais_tv'
  Future<List<ChannelData>> getAllChannels() async {
    final sheet = _spreadsheet.worksheetByTitle(_channelsSheetName);
    if (sheet == null) return [];

    final allRows = await sheet.values.allRows();
    if (allRows.isEmpty) return [];

    // 1. Pega o cabeçalho (para mapear colunas por nome)
    final headers = allRows.first.map((h) => h.toString().toLowerCase().trim()).toList();
    
    // 2. Mapeia as linhas seguintes
    final dataRows = allRows.skip(1);

    return dataRows.map((row) {
      // Cria um mapa temporário: Coluna -> Valor
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = (i < row.length) ? row[i].toString() : '';
      }
      
      // Converte para o objeto usando a fábrica
      return ChannelData.fromMap(map);
    }).where((c) => c.name.isNotEmpty && c.url.isNotEmpty).toList();
  }

  /// Obtém uma lista única e ordenada de todas as categorias
  Future<List<String>> getAllCategories() async {
    final channels = await getAllChannels();
    // Usa toSet para garantir que as categorias sejam únicas
    final categories = channels.map((c) => c.category).toSet().toList();
    categories.sort();
    return categories;
  }
}

/// Modelo de dados atualizado com factory fromMap
class ChannelData {
  final String name;
  final String url;
  final String category;
  final String imageUrl;

  ChannelData({
    required this.name,
    required this.url,
    required this.category,
    required this.imageUrl,
  });

  // Lógica para mapear dados da planilha de forma flexível
  factory ChannelData.fromMap(Map<String, String> map) {
    // Normaliza as chaves para minúsculas para facilitar a busca
    final normalizedMap = map.map((k, v) => MapEntry(k.toLowerCase().trim(), v));

    // Função auxiliar para buscar o valor usando várias chaves potenciais
    String findValue(List<String> keys, {String defaultValue = ''}) {
      for (var key in keys) {
        if (normalizedMap.containsKey(key)) {
          return normalizedMap[key]!;
        }
      }
      return defaultValue;
    }

    return ChannelData(
      name: findValue(['nome', 'canal', 'name']),
      url: findValue(['link', 'url', 'stream']),
      category: findValue(['categoria', 'grupo', 'category'], defaultValue: 'Outros'),
      imageUrl: findValue(['imagem', 'image', 'logo', 'icon']),
    );
  }
}