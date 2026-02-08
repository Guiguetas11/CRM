import 'package:universal_html/html.dart' as html;
import '../services/shared_prefs.dart';

class StayLoggedInManager {
  static Future<void> saveLoginState(String email, bool isVip, bool stayLoggedIn) async {
    if (stayLoggedIn) {
      await AppPreferences.saveLoginState(email, isVip);
      html.window.localStorage['user_email'] = email;
    }
  }

  static String? getSavedEmail() {
    return html.window.localStorage['user_email'];
  }

  static Future<void> clearLoginState() async {
    await AppPreferences.clearLoginState();
    html.window.localStorage.remove('user_email');
  }
}