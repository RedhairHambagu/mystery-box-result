import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewHelperImproved {
  static InAppWebViewController? _webViewController;
  static HeadlessInAppWebView? _headlessWebView;
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  // 预初始化WebView环境 - 快速轻量级版本
  static Future<bool> preInitialize() async {
    if (_isInitialized || _isInitializing) return _isInitialized;
    
    _isInitializing = true;
    
    try {
      print('开始快速预初始化WebView环境 - 平台: ${Platform.operatingSystem}');
      
      // 简化检查：只做基本可用性验证，1秒超时
      bool isAvailable = true;
      try {
        final userAgentFuture = InAppWebViewController.getDefaultUserAgent()
            .timeout(const Duration(seconds: 1));
        final userAgent = await userAgentFuture;
        isAvailable = userAgent != null && userAgent.isNotEmpty;
        print('快速WebView检查: $isAvailable');
      } catch (e) {
        print('快速检查超时或异常: $e');
        // 假设可用，让用户尝试
        isAvailable = true;
      }
      
      // 跳过复杂的预热过程，直接标记为已初始化
      _isInitialized = true;
      _isInitializing = false;
      print('WebView环境快速初始化完成');
      return true;
      
    } catch (e) {
      print('快速初始化失败: $e');
      _isInitializing = false;
      _isInitialized = true;
      return true;
    }
  }

  // 获取最小化设置，用于预热
  static InAppWebViewSettings _getMinimalSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      cacheEnabled: true,
      clearCache: false,
      hardwareAcceleration: true,
      transparentBackground: false,
      userAgent: _getSimpleUserAgent(),
    );
  }

  // 获取优化的WebView设置
  static InAppWebViewSettings getOptimizedSettings() {
    return InAppWebViewSettings(
      // 基础功能
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      
      // 缓存优化 - 关键改进
      cacheEnabled: true,
      clearCache: false,
      
      // 性能优化
      hardwareAcceleration: true,
      transparentBackground: false,
      
      // 平台特定优化
      useHybridComposition: Platform.isAndroid,
      allowsBackForwardNavigationGestures: Platform.isIOS || Platform.isMacOS,
      
      // 简化功能，减少初始化负担
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,
      
      // 优化的User Agent
      userAgent: _getSimpleUserAgent(),
    );
  }

  // 获取登录专用的WebView设置 - 禁用缓存确保清洁状态
  static InAppWebViewSettings getLoginSettings() {
    return InAppWebViewSettings(
      // 基础功能
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      
      // 登录时禁用缓存，确保全新状态
      cacheEnabled: false,
      clearCache: true,
      
      // 性能优化
      hardwareAcceleration: true,
      transparentBackground: false,
      
      // 平台特定优化
      useHybridComposition: Platform.isAndroid,
      allowsBackForwardNavigationGestures: Platform.isIOS || Platform.isMacOS,
      
      // 简化功能
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,
      
      // 优化的User Agent
      userAgent: _getSimpleUserAgent(),
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

  // 快速创建WebView控制器 - 改进版本
  static Future<InAppWebViewController?> createWebViewFast({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // 确保已预初始化
      if (!_isInitialized) {
        print('WebView未预初始化，开始快速初始化...');
        final initialized = await preInitialize();
        if (!initialized) {
          print('快速初始化失败');
          return null;
        }
      }

      print('开始创建WebView控制器 - 平台: ${Platform.operatingSystem}');

      final completer = Completer<InAppWebViewController?>();
      Timer? timeoutTimer;

      // 设置超时
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print('WebView创建超时');
          completer.complete(null);
        }
      });

      // 创建headless WebView
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        initialSettings: getOptimizedSettings(),
        
        onWebViewCreated: (controller) {
          _webViewController = controller;
          print('WebView控制器创建成功');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(controller);
          }
        },
        
        onLoadStart: (controller, url) {
          print('开始加载: $url');
        },
        
        onLoadStop: (controller, url) {
          print('加载完成: $url');
        },
        
        onReceivedError: (controller, request, error) {
          print('WebView错误: ${error.description}');
          // 不要因为错误就返回null，让用户可以继续尝试
        },
        
        onReceivedHttpError: (controller, request, errorResponse) {
          print('HTTP错误: ${errorResponse.statusCode}');
        },
      );

      // 启动WebView
      await _headlessWebView!.run();
      return completer.future;

    } catch (e) {
      print('创建WebView失败: $e');
      return null;
    }
  }

  // 使用onLoadResource监听网络请求 - 完全按照Electron逻辑
  static Future<Map<String, String>?> extractTokenFromMysteryBoxImproved({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<Map<String, String>?>();
    Timer? timeoutTimer;

    try {
      print('🚀 开始提取wdtoken - 使用onLoadResource监听');
      print('目标URL: https://thor.weidian.com/skittles/share.getConfig/*');

      // 设置总体超时
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print('⏰ Token提取超时');
          completer.complete(null);
        }
      });

      // 延迟3秒后开始监听 - 模拟Electron的setTimeout
      print('⏱️ 延迟3秒后开始监听...');
      await Future.delayed(const Duration(seconds: 3));

      // 创建带有资源监听的HeadlessWebView
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://h5.weidian.com/m/mystery-box/list.html#/'),
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
        ),
        initialSettings: getOptimizedSettings(),
        
        onWebViewCreated: (controller) {
          _webViewController = controller;
          print('📱 WebView创建成功，开始加载页面...');
        },
        
        onLoadStart: (controller, url) {
          print('🌐 开始加载: $url');
        },
        
        onLoadStop: (controller, url) {
          print('✅ 页面加载完成: $url');
        },
        
        // 关键：监听所有资源加载 - 这是最接近Electron onBeforeRequest的方法
        onLoadResource: (controller, resource) {
          final url = resource.url.toString();
          
          // 检查是否是目标URL - 严格按照Electron逻辑
          if (url.contains('https://thor.weidian.com/skittles/share.getConfig')) {
            print('🎯 发现目标URL: $url');
            
            if (url.contains('wdtoken=')) {
              print('🔑 发现wdtoken参数');
              
              try {
                final uri = Uri.parse(url);
                final wdtoken = uri.queryParameters['wdtoken'];
                
                if (wdtoken != null) {
                  // 提取所有以"_"开头的参数 - 严格按照Electron逻辑
                  final underscoreParams = Map.fromEntries(
                    uri.queryParameters.entries.where((e) => e.key.startsWith('_')),
                  );
                  
                  // 如果没有下划线参数，添加默认时间戳
                  if (underscoreParams.isEmpty) {
                    underscoreParams['_'] = DateTime.now().millisecondsSinceEpoch.toString();
                  }
                  
                  print('✅ 成功获取wdtoken: ${wdtoken}... (长度: ${wdtoken.length})');
                  print('📊 下划线参数: $underscoreParams');
                  
                  // 构建结果
                  final result = <String, String>{
                    'wdtoken': wdtoken,
                    'token': wdtoken, // 保持兼容性
                    'foundUrl': url,
                    'source': 'onLoadResource',
                    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
                  };
                  
                  // 添加下划线参数
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
          
          // 同时监听Cookie相关的请求 - 对应Electron的第二个监听器
          if (url.startsWith('https://logtake.weidian.com/h5collector/webcollect/3.0')) {
            print('🍪 发现Cookie相关请求: $url');
            // 这里可以进一步处理Cookie相关逻辑
          }
        },
        
        onReceivedError: (controller, request, error) {
          print('❌ WebView错误: ${error.description}');
        },
        
        onConsoleMessage: (controller, consoleMessage) {
          print('📝 Console: ${consoleMessage.message}');
        },
      );

      // 启动WebView
      await _headlessWebView!.run();
      
      return completer.future;

    } catch (e) {
      print('❌ 提取过程异常: $e');
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    }
  }

  // Cookie操作方法
  static Future<Map<String, String>> getCookies(String domain) async {
    try {
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

  // 工具方法
  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['token'] ??
          uri.queryParameters['access_token'] ??
          uri.queryParameters['wd_token'];
    } catch (e) {
      print('从URL提取token失败: $e');
      return null;
    }
  }

  static Map<String, String> extractUnderscoreParams(String url) {
    try {
      final uri = Uri.parse(url);
      final Map<String, String> underscoreParams = {};

      uri.queryParameters.forEach((key, value) {
        if (key.startsWith('_')) {
          underscoreParams[key] = value;
        }
      });

      if (underscoreParams.isEmpty) {
        underscoreParams['_'] = DateTime.now().millisecondsSinceEpoch.toString();
      }

      return underscoreParams;
    } catch (e) {
      print('提取下划线参数失败: $e');
      return {'_': DateTime.now().millisecondsSinceEpoch.toString()};
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
      // 清除所有域名的Cookies
      await CookieManager.instance().deleteAllCookies();
      
      // 特别清除微店相关域名的Cookies
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

  static Future<void> restart() async {
    print('重启WebView环境');
    await dispose();
    await Future.delayed(const Duration(milliseconds: 1000));
    await preInitialize();
  }

  // 健康检查 - 简化版本
  static Future<bool> healthCheck() async {
    try {
      if (!_isInitialized) {
        final initialized = await preInitialize();
        if (!initialized) return false;
      }

      final controller = await createWebViewFast(
        timeout: const Duration(seconds: 10)
      );
      
      if (controller == null) return false;

      // 简单测试
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
      await Future.delayed(const Duration(seconds: 2));

      final url = await controller.getUrl();
      return url != null;
    } catch (e) {
      print('健康检查失败: $e');
      return false;
    }
  }

  // 检查WebView可用性
  static Future<bool> isWebViewAvailable() async {
    try {
      final userAgent = await InAppWebViewController.getDefaultUserAgent();
      return userAgent != null && userAgent.isNotEmpty;
    } catch (e) {
      print('WebView可用性检查失败: $e');
      // macOS可能报错但仍可用
      return Platform.isMacOS;
    }
  }

  // 平台信息
  static String getPlatformInfo() {
    final platform = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion;
    return '$platform $version';
  }

  // 调试信息
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final info = <String, dynamic>{};

    info['platform'] = Platform.operatingSystem;
    info['platformVersion'] = Platform.operatingSystemVersion;
    info['isInitialized'] = _isInitialized;
    info['isInitializing'] = _isInitializing;
    info['hasWebViewController'] = _webViewController != null;
    info['hasHeadlessWebView'] = _headlessWebView != null;
    info['timestamp'] = DateTime.now().toIso8601String();

    try {
      info['userAgent'] = await InAppWebViewController.getDefaultUserAgent();
    } catch (e) {
      info['userAgentError'] = e.toString();
    }

    try {
      info['webViewAvailable'] = await isWebViewAvailable();
    } catch (e) {
      info['webViewAvailableError'] = e.toString();
    }

    return info;
  }
}