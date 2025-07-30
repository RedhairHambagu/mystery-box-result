import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _cookieKey = 'auth_cookie';
  static const String _wdTokenKey = 'wd_token';
  static const String _underscoreParamsKey = 'underscore_params';
  static const String _loginStatusKey = 'login_status';

  // 单例模式
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // 保存登录Cookie
  Future<void> saveCookie(String cookie) async {
    await _initPrefs();
    await _prefs!.setString(_cookieKey, cookie);
    await _prefs!.setBool(_loginStatusKey, true);
  }

  // 获取登录Cookie
  Future<String?> getCookie() async {
    await _initPrefs();
    return _prefs!.getString(_cookieKey);
  }

  // 保存wdToken和相关参数
  Future<void> saveWdTokenAndParams(String wdToken, Map<String, String> underscoreParams) async {
    await _initPrefs();
    await _prefs!.setString(_wdTokenKey, wdToken);
    await _prefs!.setString(_underscoreParamsKey, jsonEncode(underscoreParams));
  }

  // 获取wdToken
  Future<String?> getWdToken() async {
    await _initPrefs();
    return _prefs!.getString(_wdTokenKey);
  }

  // 获取下划线参数
  Future<Map<String, String>> getUnderscoreParams() async {
    await _initPrefs();
    final paramsString = _prefs!.getString(_underscoreParamsKey);
    if (paramsString != null) {
      final Map<String, dynamic> decoded = jsonDecode(paramsString);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    }
    return {};
  }

  // 检查登录状态
  Future<bool> isLoggedIn() async {
    await _initPrefs();
    return _prefs!.getBool(_loginStatusKey) ?? false;
  }

  // 登出 - 改进版，确保完全清除所有登录相关数据
  Future<void> logout() async {
    await _initPrefs();
    
    // 清除所有存储的登录相关数据
    await _prefs!.remove(_cookieKey);
    await _prefs!.remove(_wdTokenKey);
    await _prefs!.remove(_underscoreParamsKey);
    await _prefs!.remove(_loginStatusKey); // 完全移除登录状态，而不是设为false
    
    // 清除可能的缓存数据
    await _prefs!.commit(); // 强制写入磁盘
    
    print('AuthService: 所有登录数据已清除');
  }

  // 验证Cookie是否有效
  Future<bool> validateCookie() async {
    final cookie = await getCookie();
    if (cookie == null || cookie.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse('https://h5.weidian.com/m/mystery-box/list.html'),
        headers: {
          'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}