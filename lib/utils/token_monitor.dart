import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'webview_helper_improved.dart';
import 'token_extractor.dart';
import '../services/auth_service.dart';

class TokenMonitor {
  static Timer? _fallbackTimer;
  static bool _isMonitoring = false;
  static int _attemptCount = 0;
  static const int maxAttempts = 3;
  static const Duration fallbackDelay = Duration(seconds: 30);
  static StreamController<Map<String, String>>? _tokenController;
  static Timer? _timeoutTimer;

  static Stream<Map<String, String>> get tokenStream {
    _tokenController ??= StreamController<Map<String, String>>.broadcast();
    return _tokenController!.stream;
  }

  // 开始监听token请求，带自动回退机制
  static void startMonitoring({
    Duration timeout = const Duration(minutes: 1),
    bool enableFallback = true,
  }) {
    if (_isMonitoring) {
      print('TokenMonitor: 已在监听中');
      return;
    }

    _isMonitoring = true;
    _attemptCount++;
    print('🔍 TokenMonitor: 开始监听token请求 (尝试 $_attemptCount/$maxAttempts)');

    // 设置总体超时
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(timeout, () {
      if (_isMonitoring) {
        print('⏰ TokenMonitor: 监听超时，触发回退机制');
        _triggerFallback();
      }
    });

    // 启用自动回退机制
    if (enableFallback) {
      _startFallbackTimer();
    }
  }

  // 停止监听
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    print('🛑 TokenMonitor: 停止监听');
    _isMonitoring = false;
    _fallbackTimer?.cancel();
    _timeoutTimer?.cancel();
    _fallbackTimer = null;
    _timeoutTimer = null;
  }

  // 重置监听状态
  static void reset() {
    stopMonitoring();
    _attemptCount = 0;
    print('🔄 TokenMonitor: 重置状态');
  }

  // 处理发现的token资源
  static void handleTokenResource(String resourceUrl) {
    if (!_isMonitoring) return;

    print('🎯 TokenMonitor: 检测到资源: $resourceUrl');

    // 检查是否是目标URL
    if (resourceUrl.contains('https://thor.weidian.com/skittles/share.getConfig')) {
      print('🔑 TokenMonitor: 发现目标token URL');

      if (resourceUrl.contains('wdtoken=')) {
        _extractAndSaveToken(resourceUrl);
      } else {
        print('⚠️ TokenMonitor: URL中未找到wdtoken参数');
        // 可能需要等待更多资源加载
      }
    }
  }

  // 提取并保存token
  static void _extractAndSaveToken(String url) {
    try {
      final uri = Uri.parse(url);
      final wdtoken = uri.queryParameters['wdtoken'];

      if (wdtoken != null && wdtoken.isNotEmpty) {
        // 提取所有以"_"开头的参数
        final underscoreParams = TokenExtractor.extractUnderscoreParams(url);

        print('✅ TokenMonitor: 成功获取wdtoken: ${wdtoken}');
        print('📊 TokenMonitor: 下划线参数: $underscoreParams');

        final result = <String, String>{
          'wdtoken': wdtoken, // 保持完整token，遵循CLAUDE.md指示
          'token': wdtoken,
          'foundUrl': url,
          'source': 'TokenMonitor',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'platform': Platform.operatingSystem,
          'attempt': _attemptCount.toString(),
        };

        result.addAll(underscoreParams);

        // 保存到AuthService
        AuthService().saveWdTokenAndParams(result).then((_) {
          print('✅ TokenMonitor: Token已保存到AuthService');
          stopMonitoring(); // 成功后停止监听

          // 通知监听者
          _tokenController?.add(result);
        }).catchError((e) {
          print('❌ TokenMonitor: 保存token失败: $e');
        });
      }
    } catch (e) {
      print('❌ TokenMonitor: URL解析错误: $e');
    }
  }

  // 启动回退计时器
  static void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(fallbackDelay, () {
      if (_isMonitoring) {
        print('⏱️ TokenMonitor: 回退时间到，未检测到token请求');
        _triggerFallback();
      }
    });

    print('⏱️ TokenMonitor: 回退计时器已启动 (${fallbackDelay.inSeconds}秒)');
  }

  // 触发回退机制
  static void _triggerFallback() {
    print('🔄 TokenMonitor: 触发回退机制');

    if (_attemptCount >= maxAttempts) {
      print('❌ TokenMonitor: 已达最大尝试次数，使用备用方案');
      _useFallbackMethod();
      return;
    }

    // 尝试使用TokenExtractor直接提取
    _attemptTokenExtraction();
  }

  // 使用TokenExtractor进行回退提取
  static void _attemptTokenExtraction() async {
    print('🚀 TokenMonitor: 使用TokenExtractor进行回退提取');

    try {
      final result = await TokenExtractor.extractToken(
        timeout: const Duration(minutes: 1),
      );

      if (result != null) {
        print('✅ TokenMonitor: 回退提取成功');
        _tokenController?.add(result);
        stopMonitoring();
      } else {
        print('❌ TokenMonitor: 回退提取失败');
        
        if (_attemptCount < maxAttempts) {
          // 重新开始监听
          stopMonitoring();
          await Future.delayed(const Duration(seconds: 2));
          startMonitoring();
        } else {
          _useFallbackMethod();
        }
      }
    } catch (e) {
      print('❌ TokenMonitor: 回退提取异常: $e');
      _useFallbackMethod();
    }
  }

  // 最终备用方案
  static void _useFallbackMethod() {
    print('🆘 TokenMonitor: 使用最终备用方案');
    
    // 通知使用手动模式
    final fallbackResult = <String, String>{
      'status': 'fallback',
      'message': '自动token获取失败，请手动登录',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'attempts': _attemptCount.toString(),
    };
    
    _tokenController?.add(fallbackResult);
    stopMonitoring();
  }

  // 检查是否正在监听
  static bool get isMonitoring => _isMonitoring;

  // 获取当前尝试次数
  static int get attemptCount => _attemptCount;

  // 关闭资源
  static void dispose() {
    stopMonitoring();
    _tokenController?.close();
    _tokenController = null;
  }

  // 调试信息
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isMonitoring': _isMonitoring,
      'attemptCount': _attemptCount,
      'maxAttempts': maxAttempts,
      'fallbackDelaySeconds': fallbackDelay.inSeconds,
      'hasFallbackTimer': _fallbackTimer != null,
      'hasTimeoutTimer': _timeoutTimer != null,
      'hasTokenController': _tokenController != null,
      'platform': Platform.operatingSystem,
    };
  }
}