class AppState {
  AppState._();
  static final instance = AppState._();

  /// Aqui vamos armazenar a linha completa do usuário VIP
  Map<String, String>? vipUserRow;

  /// Retorna true se, na planilha, a coluna 'vip' estiver marcada como 'sim'
  bool get isVipActive {
    final row = vipUserRow;
    if (row == null) return false;
    return row['vip']?.toLowerCase() == 'ativo';
  }
}
