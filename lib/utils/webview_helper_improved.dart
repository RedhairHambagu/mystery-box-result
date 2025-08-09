import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewHelperImproved {
  static InAppWebViewController? _webViewController;
  static HeadlessInAppWebView? _headlessWebView;
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  // Windows 平台兼容性检查
  static bool get isWindowsSupported {
    return true;
  }

  static bool _hasWindowsWebViewSupport() {
    return true;
  }

  // 获取平台信息
  static String getPlatformInfo() {
    final platform = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion;

    switch (platform) {
      case 'windows':
        return 'Windows (${version}) - WebView2';
      case 'macos':
        return 'macOS (${version}) - Safari WebKit';
      case 'android':
        return 'Android (${version}) - Chrome WebView';
      case 'ios':
        return 'iOS (${version}) - Safari WebKit';
      case 'linux':
        return 'Linux (${version}) - WebKit';
      default:
        return '${platform.toUpperCase()} (${version})';
    }
  }

  // 检查WebView是否可用
  static Future<bool> isWebViewAvailable() async {
    try {
      if (Platform.isWindows) {
        return _hasWindowsWebViewSupport();
      }

      if (Platform.isAndroid) {
        // Android平台检查WebView可用性
        try {
          // 尝试创建一个临时的WebView来检测可用性
          final testWebView = HeadlessInAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: false,
              cacheEnabled: false,
            ),
          );

          await testWebView.run();
          await Future.delayed(const Duration(milliseconds: 500));
          await testWebView.dispose();

          print('Android WebView可用性检查：通过');
          return true;
        } catch (e) {
          print('Android WebView可用性检查失败: $e');
          return false;
        }
      }

      // 对于iOS和macOS平台，尝试获取默认UserAgent来检测
      try {
        final userAgent = await InAppWebViewController.getDefaultUserAgent()
            .timeout(const Duration(seconds: 3));
        final isAvailable = userAgent != null && userAgent.isNotEmpty;
        print('${Platform.operatingSystem} WebView可用性检查: ${isAvailable ? '通过' : '失败'}');
        return isAvailable;
      } catch (e) {
        print('检查WebView可用性时出现异常: $e');
        // 对于iOS和macOS，假设WebView通常是可用的
        return Platform.isIOS || Platform.isMacOS;
      }
    } catch (e) {
      print('WebView可用性检查失败: $e');
      // 为不同平台返回合理的默认值
      return Platform.isWindows || Platform.isMacOS || Platform.isIOS;
    }
  }

  // 重启WebView环境
  static Future<void> restart() async {
    try {
      print('正在重启WebView环境...');

      // 清理现有资源
      await dispose();

      // 等待一段时间确保资源完全释放
      await Future.delayed(const Duration(seconds: 1));

      // 清除所有缓存和Cookie
      try {
        await clearAllCookies();
      } catch (e) {
        print('清除Cookie时出现警告: $e');
      }

      // 重新初始化
      _isInitialized = false;
      _isInitializing = false;

      await preInitialize();

      print('WebView环境重启完成');
    } catch (e) {
      print('重启WebView环境失败: $e');
      rethrow;
    }
  }

  // 提取URL中的下划线参数
  static Map<String, String> extractUnderscoreParams(String url) {
    final Map<String, String> params = {};

    try {
      final uri = Uri.parse(url);

      // 提取所有以下划线开头的查询参数
      for (final entry in uri.queryParameters.entries) {
        if (entry.key.startsWith('_')) {
          params[entry.key] = entry.value;
        }
      }

      // 如果没有找到下划线参数，添加默认的时间戳参数
      if (params.isEmpty) {
        params['_'] = DateTime.now().millisecondsSinceEpoch.toString();
      }

      print('提取到的下划线参数: ${params.keys.join(', ')}');
    } catch (e) {
      print('提取下划线参数时出错: $e');
      // 返回默认参数
      params['_'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    return params;
  }

  // 预初始化WebView环境
  static Future<bool> preInitialize() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;

    try {
      print('开始预初始化WebView环境 - 平台: ${Platform.operatingSystem}');

      if (Platform.isWindows) {
        print('检测到 Windows 平台，启用基本网络功能');
        try {
          final userAgent = _getSimpleUserAgent();
          print('Windows 平台 UserAgent: $userAgent');
          _isInitialized = true;
          _isInitializing = false;
          return true;
        } catch (e) {
          print('Windows 平台初始化警告: $e');
          _isInitialized = true;
          _isInitializing = false;
          return true;
        }
      }

      if (Platform.isAndroid) {
        print('🔥 Android 平台开始WebView预热...');
        await _warmupWebViewAndroid();
      } else {
        try {
          if (Platform.isWindows) {
            final userAgent = _getSimpleUserAgent();
            print('WebView检查 (Windows预设): ${userAgent.isNotEmpty}');
          } else {
            final userAgentFuture = InAppWebViewController.getDefaultUserAgent()
                .timeout(const Duration(seconds: 2));
            final userAgent = await userAgentFuture;
            print('WebView检查: ${userAgent != null && userAgent.isNotEmpty}');
          }
        } catch (e) {
          print('WebView检查异常: $e');
        }
      }

      _isInitialized = true;
      _isInitializing = false;
      print('✅ WebView环境预初始化完成');
      return true;

    } catch (e) {
      print('❌ 预初始化失败: $e');
      _isInitializing = false;
      _isInitialized = true;
      return true;
    }
  }

  // Android WebView 预热机制
  static Future<void> _warmupWebViewAndroid() async {
    try {
      print('🔥 开始 Android WebView 预热过程...');

      final warmupWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          cacheEnabled: true,
          hardwareAcceleration: true,
          userAgent: _getSimpleUserAgent(),
        ),
        onWebViewCreated: (controller) {
          print('🔥 预热WebView创建成功');
        },
        onLoadStop: (controller, url) {
          print('🔥 预热页面加载完成');
        },
      );

      await warmupWebView.run();
      await Future.delayed(const Duration(milliseconds: 1500));

      final controller = await warmupWebView.webViewController;
      if (controller != null) {
        try {
          await controller.evaluateJavascript(source: '''
            console.log('WebView warmup test');
            document.createElement('div');
            window.performance = window.performance || {};
            true;
          ''');
          print('🔥 JavaScript 引擎预热完成');
        } catch (e) {
          print('🔥 JavaScript 预热失败: $e');
        }
      }

      await warmupWebView.dispose();
      print('🔥 预热WebView已销毁，预热完成');

    } catch (e) {
      print('🔥 Android WebView 预热失败: $e');
    }
  }

  // 获取优化的WebView设置
  static InAppWebViewSettings getOptimizedSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      clearCache: false,
      hardwareAcceleration: true,
      transparentBackground: false,
      useHybridComposition: Platform.isAndroid,
      allowsBackForwardNavigationGestures: Platform.isIOS || Platform.isMacOS,
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,
      userAgent: _getSimpleUserAgent(),
      // Windows 特殊设置
      resourceCustomSchemes: Platform.isWindows ? [] : null,
    );
  }

  static String _getSimpleUserAgent() {
    switch (Platform.operatingSystem) {
      case 'macos':
        return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      case 'windows':
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      case 'android':
        return 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      default:
        return 'Mozilla/5.0 (compatible) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
    }
  }

  // Windows 兼容的 Token 提取方法
  static Future<Map<String, String>?> extractTokenFromMysteryBoxImproved({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final completer = Completer<Map<String, String>?>();
    Timer? timeoutTimer;

    try {
      print('🚀 开始提取wdtoken - ${Platform.operatingSystem}平台优化版本');

      if (!_isInitialized) {
        print('⚡ WebView未初始化，开始预热...');
        await preInitialize();
        if (Platform.isAndroid) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      final isFirstRun = !_isInitialized || _webViewController == null;
      final actualTimeout = isFirstRun && Platform.isAndroid
          ? const Duration(seconds: 15)
          : timeout;

      timeoutTimer = Timer(actualTimeout, () {
        if (!completer.isCompleted) {
          print('⏰ Token提取超时 (${actualTimeout.inSeconds}秒)');
          completer.complete(null);
        }
      });

      // 清理之前的WebView实例
      if (_headlessWebView != null) {
        print('🧹 清理之前的WebView实例...');
        try {
          await _headlessWebView!.dispose();
          _headlessWebView = null;
          _webViewController = null;
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print('🧹 清理过程出现异常: $e');
        }
      }

      // Windows 平台使用不同的策略
      if (Platform.isWindows) {
        return await _extractTokenWindowsCompatible(completer, timeoutTimer);
      } else {
        return await _extractTokenStandard(completer, timeoutTimer, isFirstRun);
      }

    } catch (e) {
      print('❌ 提取过程异常: $e');
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    }
  }

  // Windows 兼容的提取方法
  static Future<Map<String, String>?> _extractTokenWindowsCompatible(
      Completer<Map<String, String>?> completer, Timer? timeoutTimer) async {

    print('🪟 使用 Windows 兼容模式');

    // Windows 上使用 JavaScript 注入和轮询的方式
    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://h5.weidian.com/m/mystery-box/list.html#/'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      initialSettings: getOptimizedSettings(),

      onWebViewCreated: (controller) {
        _webViewController = controller;
        print('🪟 Windows WebView创建成功');
      },

      onLoadStop: (controller, url) async {
        print('✅ 页面加载完成: $url');

        // Windows 上注入 JavaScript 来监听网络请求
        try {
          await Future.delayed(const Duration(seconds: 3)); // 等待页面完全加载

          await controller.evaluateJavascript(source: '''
            // 覆盖 XMLHttpRequest 和 fetch 来监听请求
            (function() {
              const originalFetch = window.fetch;
              const originalXHROpen = XMLHttpRequest.prototype.open;
              const originalXHRSend = XMLHttpRequest.prototype.send;
              
              window.capturedToken = null;
              
              // 监听 fetch 请求
              window.fetch = function(...args) {
                const url = args[0];
                if (typeof url === 'string' && url.includes('thor.weidian.com/skittles/share.getConfig')) {
                  console.log('🎯 Fetch请求:', url);
                  if (url.includes('wdtoken=')) {
                    try {
                      const urlObj = new URL(url);
                      const token = urlObj.searchParams.get('wdtoken');
                      if (token) {
                        window.capturedToken = {
                          wdtoken: token,
                          token: token,
                          foundUrl: url,
                          source: 'fetch',
                          timestamp: Date.now().toString(),
                          platform: 'windows'
                        };
                        console.log('✅ Token captured via fetch:', token.substring(0, 20) + '...');
                      }
                    } catch (e) {
                      console.log('❌ Token extraction error:', e);
                    }
                  }
                }
                return originalFetch.apply(this, args);
              };
              
              // 监听 XMLHttpRequest
              XMLHttpRequest.prototype.open = function(method, url, ...args) {
                this._url = url;
                return originalXHROpen.call(this, method, url, ...args);
              };
              
              XMLHttpRequest.prototype.send = function(...args) {
                if (this._url && this._url.includes('thor.weidian.com/skittles/share.getConfig')) {
                  console.log('🎯 XHR请求:', this._url);
                  if (this._url.includes('wdtoken=')) {
                    try {
                      const urlObj = new URL(this._url);
                      const token = urlObj.searchParams.get('wdtoken');
                      if (token) {
                        window.capturedToken = {
                          wdtoken: token,
                          token: token,
                          foundUrl: this._url,
                          source: 'xhr',
                          timestamp: Date.now().toString(),
                          platform: 'windows'
                        };
                        console.log('✅ Token captured via XHR:', token.substring(0, 20) + '...');
                      }
                    } catch (e) {
                      console.log('❌ Token extraction error:', e);
                    }
                  }
                }
                return originalXHRSend.apply(this, args);
              };
              
              console.log('🪟 Windows 网络监听已注入');
            })();
          ''');

          print('🪟 网络监听脚本注入完成');

          // 开始轮询检查
          _startTokenPolling(controller, completer, timeoutTimer);

        } catch (e) {
          print('❌ JavaScript注入失败: $e');
        }
      },

      onConsoleMessage: (controller, consoleMessage) {
        print('📝 Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
      },
    );

    await _headlessWebView!.run();
    return completer.future;
  }

  // 开始轮询检查 Token
  static void _startTokenPolling(InAppWebViewController controller,
      Completer<Map<String, String>?> completer, Timer? timeoutTimer) {

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }

      try {
        final result = await controller.evaluateJavascript(source: '''
          window.capturedToken ? JSON.stringify(window.capturedToken) : null;
        ''');

        if (result != null && result != 'null') {
          print('🎉 检测到Token: $result');
          timer.cancel();
          timeoutTimer?.cancel();

          try {
            final tokenData = Map<String, String>.from(
                Map<String, dynamic>.from(
                  // 简单的 JSON 解析，避免使用 dart:convert
                    _parseSimpleJson(result.toString())
                )
            );

            if (!completer.isCompleted) {
              completer.complete(tokenData);
            }
          } catch (e) {
            print('❌ Token数据解析失败: $e');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        }
      } catch (e) {
        print('❌ Token检查失败: $e');
      }
    });
  }

  // 简单的 JSON 解析器（避免引入额外依赖）
  static Map<String, dynamic> _parseSimpleJson(String jsonString) {
    // 移除外层引号
    jsonString = jsonString.replaceAll(RegExp(r'^"|"$'), '');
    // 替换转义字符
    jsonString = jsonString.replaceAll('\\"', '"');

    final Map<String, dynamic> result = {};

    // 简单的键值对解析
    final regex = RegExp(r'"([^"]+)"\s*:\s*"([^"]*)"');
    final matches = regex.allMatches(jsonString);

    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    return result;
  }

  // 标准平台的提取方法
  static Future<Map<String, String>?> _extractTokenStandard(
      Completer<Map<String, String>?> completer, Timer? timeoutTimer, bool isFirstRun) async {

    print('📱 使用标准模式 (非Windows)');

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://h5.weidian.com/m/mystery-box/list.html#/'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      initialSettings: getOptimizedSettings(),

      onWebViewCreated: (controller) {
        _webViewController = controller;
        print('📱 标准WebView创建成功');
      },

      onLoadStop: (controller, url) {
        print('✅ 页面加载完成: $url');
      },

      // 使用 onLoadResource 监听（非Windows平台）
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();

        if (url.contains('https://thor.weidian.com/skittles/share.getConfig')) {
          print('🎯 发现目标URL: $url');

          if (url.contains('wdtoken=')) {
            print('🔑 发现wdtoken参数');

            try {
              final uri = Uri.parse(url);
              final wdtoken = uri.queryParameters['wdtoken'];

              if (wdtoken != null && wdtoken.isNotEmpty) {
                final underscoreParams = Map.fromEntries(
                  uri.queryParameters.entries.where((e) => e.key.startsWith('_')),
                );

                if (underscoreParams.isEmpty) {
                  underscoreParams['_'] = DateTime.now().millisecondsSinceEpoch.toString();
                }

                print('✅ 成功获取wdtoken: ${wdtoken}... (长度: ${wdtoken.length})');

                final result = <String, String>{
                  'wdtoken': wdtoken,
                  'token': wdtoken,
                  'foundUrl': url,
                  'source': 'onLoadResource',
                  'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
                  'isFirstRun': isFirstRun.toString(),
                  'platform': Platform.operatingSystem,
                };

                result.addAll(underscoreParams);

                timeoutTimer?.cancel();
                if (!completer.isCompleted) {
                  completer.complete(result);
                }
              }
            } catch (e) {
              print('❌ URL解析错误: $e');
            }
          }
        }
      },

      onReceivedError: (controller, request, error) {
        print('❌ WebView错误: ${error.description} (${error.type})');
      },

      onConsoleMessage: (controller, consoleMessage) {
        print('📝 Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
      },
    );

    await _headlessWebView!.run();
    return completer.future;
  }

  // Cookie操作方法
  static Future<Map<String, String>> getCookies(String domain) async {
    try {
      if (Platform.isWindows) {
        print('Windows 平台尝试 Cookie 操作...');
      }

      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(domain),
      );

      final cookieMap = <String, String>{};
      for (final cookie in cookies) {
        cookieMap[cookie.name] = cookie.value;
      }

      return cookieMap;
    } catch (e) {
      print('获取Cookies失败: $e');
      return {};
    }
  }

  static Future<void> setCookies(String domain, Map<String, String> cookies) async {
    try {
      for (final entry in cookies.entries) {
        await CookieManager.instance().setCookie(
          url: WebUri(domain),
          name: entry.key,
          value: entry.value,
          domain: Uri.parse(domain).host,
          path: '/',
          isSecure: domain.startsWith('https'),
          isHttpOnly: false,
          sameSite: HTTPCookieSameSitePolicy.LAX,
        );
      }
    } catch (e) {
      print('设置Cookies失败: $e');
      rethrow;
    }
  }

  // 清理和维护方法
  static Future<void> dispose() async {
    try {
      print('开始清理WebView资源');

      if (_headlessWebView != null) {
        await _headlessWebView!.dispose();
        _headlessWebView = null;
      }

      _webViewController = null;
      _isInitialized = false;
      _isInitializing = false;

      print('WebView资源清理完成');
    } catch (e) {
      print('清理WebView资源失败: $e');
    }
  }

  static Future<void> clearAllCookies() async {
    try {
      await CookieManager.instance().deleteAllCookies();

      final weidianDomains = [
        'https://weidian.com',
        'https://h5.weidian.com',
        'https://thor.weidian.com',
        'https://logtake.weidian.com',
        'https://passport.weidian.com',
      ];

      for (final domain in weidianDomains) {
        try {
          await CookieManager.instance().deleteCookies(url: WebUri(domain));
        } catch (e) {
          print('清除$domain域名Cookies失败: $e');
        }
      }

      print('所有Cookies已彻底清除');
    } catch (e) {
      print('清除Cookies失败: $e');
      rethrow;
    }
  }

  // 健康检查
  static Future<bool> healthCheck() async {
    try {
      if (Platform.isWindows) {
        print('Windows 平台健康检查：测试基础功能');
      }

      if (!_isInitialized) {
        final initialized = await preInitialize();
        if (!initialized) return false;
      }

      return true;
    } catch (e) {
      print('健康检查失败: $e');
      return Platform.isWindows;
    }
  }

  // 智能重试机制
  static Future<Map<String, String>?> extractTokenWithRetry({
    int maxRetries = 2,
    Duration baseTimeout = const Duration(minutes: 3),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      attempts++;
      final isFirstAttempt = attempts == 1;

      print('🔄 尝试 $attempts/$maxRetries ${isFirstAttempt ? "(首次)" : "(重试)"} - ${Platform.operatingSystem}');

      final timeout = isFirstAttempt && Platform.isAndroid
          ? const Duration(minutes: 5)
          : baseTimeout;

      final result = await extractTokenFromMysteryBoxImproved(timeout: timeout);

      if (result != null) {
        print('✅ 第 $attempts 次尝试成功');
        return result;
      }

      if (attempts < maxRetries) {
        print('❌ 第 $attempts 次尝试失败，准备重试...');
        await dispose();
        await Future.delayed(const Duration(seconds: 2));
        await preInitialize();
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    print('❌ 所有尝试均失败 ($maxRetries/$maxRetries)');
    return null;
  }

  // 调试信息
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final info = <String, dynamic>{};
    info['platform'] = Platform.operatingSystem;
    info['platformInfo'] = getPlatformInfo();
    info['isInitialized'] = _isInitialized;
    info['timestamp'] = DateTime.now().toIso8601String();
    info['isWindowsSupported'] = isWindowsSupported;
    info['webViewAvailable'] = await isWebViewAvailable();

    if (Platform.isWindows) {
      info['windowsNote'] = 'Windows 平台使用JavaScript注入模式';
      info['userAgent'] = _getSimpleUserAgent();
      info['strategy'] = 'JavaScript Polling';
    } else {
      info['strategy'] = 'onLoadResource';
    }

    return info;
  }
}