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

  // 保存登录Cookie和Token（如果可用）
  Future<void> saveLoginData(String cookie, {Map<String, String>? tokenResult}) async {
    await _initPrefs();
    
    // 保存cookie
    await _prefs!.setString(_cookieKey, cookie);
    await _prefs!.setBool(_loginStatusKey, true);
    
    // 如果有token数据，也保存
    if (tokenResult != null) {
      await saveWdTokenAndParams(tokenResult);
      print('AuthService: Cookie和Token都已保存');
    } else {
      print('AuthService: 仅保存了Cookie，Token需要后续获取');
    }
  }

  // 获取登录Cookie
  Future<String?> getCookie() async {
    await _initPrefs();
    return _prefs!.getString(_cookieKey);
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

  // 清除wdToken和相关参数
  Future<void> clearWdToken() async {
    await _initPrefs();
    await _prefs!.remove(_wdTokenKey);
    await _prefs!.remove(_underscoreParamsKey);
  }

  // 保存token结果 - 支持Map<String, String>格式
  Future<void> saveWdTokenAndParams(Map<String, String> tokenResult) async {
    await _initPrefs();
    
    final wdToken = tokenResult['wdtoken'] ?? tokenResult['token'];
    if (wdToken != null) {
      await _prefs!.setString(_wdTokenKey, wdToken);
      
      // 提取所有以"_"开头的参数
      final underscoreParams = <String, String>{};
      tokenResult.forEach((key, value) {
        if (key.startsWith('_')) {
          underscoreParams[key] = value;
        }
      });
      
      if (underscoreParams.isNotEmpty) {
        await _prefs!.setString(_underscoreParamsKey, jsonEncode(underscoreParams));
      }
    }
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

  // 尝试从登录后的网页响应中提取token
  Future<Map<String, String>?> tryExtractTokenFromLoginResponse() async {
    final cookie = await getCookie();
    if (cookie == null || cookie.isEmpty) return null;

    try {
      print('AuthService: 尝试从登录响应中提取token');
      
      // 访问盲盒页面，看是否能直接获取token
      final response = await http.get(
        Uri.parse('https://h5.weidian.com/m/mystery-box/list.html#/'),
        headers: {
          'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final html = response.body;
        
        // 尝试从HTML中提取token相关信息
        final tokenRegex = RegExp(r'wdtoken["\s=:]+([a-zA-Z0-9_-]+)');
        final match = tokenRegex.firstMatch(html);
        
        if (match != null && match.group(1) != null) {
          final token = match.group(1)!;
          print('AuthService: 从HTML中找到token: ${token}...');
          
          return {
            'wdtoken': token,
            'token': token,
            'source': 'login_html_extraction',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          };
        }
        
        print('AuthService: HTML中未找到token，需要通过WebView获取');
      }
    } catch (e) {
      print('AuthService: 从登录响应提取token失败: $e');
    }
    
    return null;
  }
}