// shared_prefs.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class AppPreferences {
  static Future<void> saveLoginState(String email, bool isVip) async {
    if (kIsWeb) {
      html.window.localStorage['user_email'] = email;
      html.window.localStorage['is_vip'] = isVip.toString();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setBool('is_vip', isVip);
    }
  }

  static Future<Map<String, dynamic>> getLoginState() async {
    if (kIsWeb) {
      return {
        'email': html.window.localStorage['user_email'],
        'is_vip': html.window.localStorage['is_vip'] == 'true',
      };
    } else {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('user_email'),
        'is_vip': prefs.getBool('is_vip') ?? false,
      };
    }
  }

  static Future<void> clearLoginState() async {
    if (kIsWeb) {
      html.window.localStorage.remove('user_email');
      html.window.localStorage.remove('is_vip');
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('is_vip');
    }
  }
}