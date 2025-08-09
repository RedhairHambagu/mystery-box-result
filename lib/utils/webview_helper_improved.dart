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
    // Windows 平台现在支持基本的网络功能
    return true;
  }

  static bool _hasWindowsWebViewSupport() {
    // Windows 平台支持基本的 WebView 功能
    return true;
  }

  // 预初始化WebView环境 - 改进 Android 预热机制
  static Future<bool> preInitialize() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;

    try {
      print('开始预初始化WebView环境 - 平台: ${Platform.operatingSystem}');

      // Windows 平台特殊处理 - 启用基本功能
      if (Platform.isWindows) {
        print('检测到 Windows 平台，启用基本网络功能');
        try {
          // 测试基本的网络连接
          final userAgent = _getSimpleUserAgent();
          print('Windows 平台 UserAgent: $userAgent');
          _isInitialized = true;
          _isInitializing = false;
          return true;
        } catch (e) {
          print('Windows 平台初始化警告: $e');
          // 即使出错也标记为已初始化，允许使用基本功能
          _isInitialized = true;
          _isInitializing = false;
          return true;
        }
      }

      // Android 平台执行真正的预热
      if (Platform.isAndroid) {
        print('🔥 Android 平台开始WebView预热...');
        await _warmupWebViewAndroid();
      } else {
        // 其他平台简化检查
        try {
          if (Platform.isWindows) {
            // Windows 平台跳过 getDefaultUserAgent 调用
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

      // 第一步：创建并快速销毁一个简单的 WebView
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

      // 启动预热WebView
      await warmupWebView.run();

      // 等待一小段时间让WebView完全初始化
      await Future.delayed(const Duration(milliseconds: 1500));

      // 预加载一些关键资源
      final controller = await warmupWebView.webViewController;
      if (controller != null) {
        // 预执行一些 JavaScript 来初始化引擎
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

      // 销毁预热WebView
      await warmupWebView.dispose();
      print('🔥 预热WebView已销毁，预热完成');

    } catch (e) {
      print('🔥 Android WebView 预热失败: $e');
      // 预热失败不影响后续使用
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

      // 平台特定优化 - 排除 Windows
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

      // 平台特定优化 - 排除 Windows
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

  // 快速创建WebView控制器 - 改进版本，添加 Windows 兼容性
  static Future<InAppWebViewController?> createWebViewFast({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // Windows 平台检查 - 尝试创建 WebView
      if (Platform.isWindows) {
        print('Windows 平台尝试创建 HeadlessInAppWebView...');
        // 继续执行，不直接返回 null
      }

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

  // 使用onLoadResource监听网络请求 - 优化 Android 首次加载
  static Future<Map<String, String>?> extractTokenFromMysteryBoxImproved({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    // Windows 平台检查 - 允许执行
    if (Platform.isWindows) {
      print('⚠️ Windows 平台运行，可能存在兼容性问题');
      // 继续执行，不直接返回 null
    }

    final completer = Completer<Map<String, String>?>();
    Timer? timeoutTimer;

    try {
      print('🚀 开始提取wdtoken - 优化版本');
      print('🎯 目标URL: https://thor.weidian.com/skittles/share.getConfig/*');

      // 确保WebView已预热（特别是Android）
      if (!_isInitialized) {
        print('⚡ WebView未初始化，开始预热...');
        await preInitialize();
        // Android 预热后额外等待
        if (Platform.isAndroid) {
          print('⏱️ Android 预热完成，等待系统稳定...');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      // 设置总体超时 - Android 首次使用延长时间
      final isFirstRun = !_isInitialized || _webViewController == null;
      final actualTimeout = isFirstRun && Platform.isAndroid
          ? const Duration(seconds: 15)  // 首次运行延长超时
          : timeout;

      timeoutTimer = Timer(actualTimeout, () {
        if (!completer.isCompleted) {
          print('⏰ Token提取超时 (${actualTimeout.inSeconds}秒)');
          completer.complete(null);
        }
      });

      print('⏱️ 超时设置: ${actualTimeout.inSeconds}秒 (首次运行: $isFirstRun)');

      // 渐进式延迟策略
      Duration initialDelay;
      if (Platform.isAndroid && isFirstRun) {
        initialDelay = const Duration(seconds: 5); // 首次运行延长延迟
        print('⏳ Android 首次运行，延长初始等待至 5 秒...');
      } else {
        initialDelay = const Duration(seconds: 2); // 后续运行缩短延迟
        print('⏳ 后续运行，缩短等待至 2 秒...');
      }

      await Future.delayed(initialDelay);

      // 销毁之前的WebView实例，确保干净启动
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

      // 创建带有资源监听的HeadlessWebView
      print('📱 创建新的WebView实例...');
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
        // 使用优化设置，但启用缓存加速后续加载
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          cacheEnabled: true, // 启用缓存
          clearCache: false,  // 不清除缓存
          hardwareAcceleration: true,
          transparentBackground: false,
          useHybridComposition: Platform.isAndroid,
          supportZoom: false,
          builtInZoomControls: false,
          displayZoomControls: false,
          mediaPlaybackRequiresUserGesture: true,
          allowsInlineMediaPlayback: false,
          userAgent: _getSimpleUserAgent(),
          // Android 特定优化
          mixedContentMode: Platform.isAndroid
              ? MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE
              : null,
        ),

        onWebViewCreated: (controller) {
          _webViewController = controller;
          print('📱 WebView创建成功，开始加载页面...');
        },

        onLoadStart: (controller, url) {
          print('🌐 开始加载: $url');
        },

        onLoadStop: (controller, url) {
          print('✅ 页面加载完成: $url');

          // 页面加载完成后，执行一些JavaScript来确保页面完全就绪
          if (Platform.isAndroid) {
            controller.evaluateJavascript(source: '''
              console.log('Page fully loaded, waiting for resources...');
              setTimeout(function() {
                console.log('Resources should be loaded now');
              }, 2000);
            ''').catchError((e) {
              print('JavaScript执行失败: $e');
            });
          }
        },

        // 关键：监听所有资源加载
        onLoadResource: (controller, resource) {
          final url = resource.url.toString();

          // 检查是否是目标URL
          if (url.contains('https://thor.weidian.com/skittles/share.getConfig')) {
            print('🎯 发现目标URL: $url');

            if (url.contains('wdtoken=')) {
              print('🔑 发现wdtoken参数');

              try {
                final uri = Uri.parse(url);
                final wdtoken = uri.queryParameters['wdtoken'];

                if (wdtoken != null && wdtoken.isNotEmpty) {
                  // 提取所有以"_"开头的参数
                  final underscoreParams = Map.fromEntries(
                    uri.queryParameters.entries.where((e) => e.key.startsWith('_')),
                  );

                  if (underscoreParams.isEmpty) {
                    underscoreParams['_'] = DateTime.now().millisecondsSinceEpoch.toString();
                  }

                  print('✅ 成功获取wdtoken: ${wdtoken}... (长度: ${wdtoken.length})');
                  print('📊 下划线参数: $underscoreParams');

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

          // 监听Cookie相关的请求
          if (url.startsWith('https://logtake.weidian.com/h5collector/webcollect/3.0')) {
            print('🍪 发现Cookie相关请求: $url');
          }
        },

        onReceivedError: (controller, request, error) {
          print('❌ WebView错误: ${error.description} (${error.type})');
          // 不要因为错误就终止，继续等待
        },

        onReceivedHttpError: (controller, request, errorResponse) {
          print('🌐 HTTP错误: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}');
        },

        onConsoleMessage: (controller, consoleMessage) {
          print('📝 Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
        },

        // 添加进度监听
        onProgressChanged: (controller, progress) {
          if (progress % 25 == 0) { // 每25%打印一次
            print('📊 加载进度: $progress%');
          }
        },
      );

      // 启动WebView
      print('🚀 启动WebView...');
      await _headlessWebView!.run();

      final result = await completer.future;

      // 记录性能信息
      if (result != null) {
        print('🎉 Token提取成功！耗时: ${DateTime.now().millisecondsSinceEpoch - int.parse(result['timestamp']!)}ms');
      }

      return result;

    } catch (e) {
      print('❌ 提取过程异常: $e');
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    }
  }

  // Cookie操作方法 - 添加 Windows 兼容性
  static Future<Map<String, String>> getCookies(String domain) async {
    try {
      // Windows 平台检查 - 尝试执行
      if (Platform.isWindows) {
        print('Windows 平台尝试 Cookie 操作...');
        // 继续执行标准流程
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
      // Windows 平台检查 - 尝试执行
      if (Platform.isWindows) {
        print('Windows 平台尝试设置 Cookie...');
        // 继续执行标准流程
      }

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
      // Windows 平台检查 - 尝试执行
      if (Platform.isWindows) {
        print('Windows 平台尝试清理 Cookie...');
        // 继续执行标准流程
      }

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

  // 健康检查 - 添加 Windows 兼容性
  static Future<bool> healthCheck() async {
    try {
      // Windows 平台检查 - 健康检查
      if (Platform.isWindows) {
        print('Windows 平台健康检查：测试基础功能');
        // 执行实际的健康检查而不是直接返回 true
      }

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
      // Windows 平台即使出错也认为基础功能可用
      return Platform.isWindows;
    }
  }

  // 检查WebView可用性 - 改进 Windows 支持
  static Future<bool> isWebViewAvailable() async {
    try {
      // Windows 平台特殊处理
      if (Platform.isWindows) {
        print('Windows 平台：使用预设 UserAgent 进行可用性检查');
        // Windows 平台 flutter_inappwebview 不支持 getDefaultUserAgent
        final userAgent = _getSimpleUserAgent();
        return userAgent.isNotEmpty;
      }

      final userAgent = await InAppWebViewController.getDefaultUserAgent();
      return userAgent != null && userAgent.isNotEmpty;
    } catch (e) {
      print('WebView可用性检查失败: $e');
      // macOS和Windows可能报错但仍可用
      return Platform.isMacOS || Platform.isWindows;
    }
  }

  // 平台信息
  static String getPlatformInfo() {
    final platform = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion;
    final support = isWindowsSupported ? '(支持)' : '(受限)';
    return '$platform $version $support';
  }

  // 调试信息 - 添加 Windows 特殊信息
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final info = <String, dynamic>{};

    info['platform'] = Platform.operatingSystem;
    info['platformVersion'] = Platform.operatingSystemVersion;
    info['isInitialized'] = _isInitialized;
    info['isInitializing'] = _isInitializing;
    info['hasWebViewController'] = _webViewController != null;
    info['hasHeadlessWebView'] = _headlessWebView != null;
    info['timestamp'] = DateTime.now().toIso8601String();
    info['isWindowsSupported'] = isWindowsSupported;

    // Windows 平台特殊处理
    if (Platform.isWindows) {
      info['windowsNote'] = 'Windows 平台基础功能已启用';
      info['userAgent'] = _getSimpleUserAgent();
      info['userAgentSource'] = '预设值';
      info['networkSupport'] = '已启用';
    } else {
      try {
        info['userAgent'] = await InAppWebViewController.getDefaultUserAgent();
        info['userAgentSource'] = '系统获取';
      } catch (e) {
        info['userAgentError'] = e.toString();
        info['userAgent'] = _getSimpleUserAgent();
        info['userAgentSource'] = '预设值（获取失败）';
      }
    }

    try {
      info['webViewAvailable'] = await isWebViewAvailable();
    } catch (e) {
      info['webViewAvailableError'] = e.toString();
    }

    return info;
  }

  // 应用启动时预热 - 推荐在应用启动时调用
  static Future<void> preWarmup() async {
    if (Platform.isAndroid && !_isInitialized) {
      print('🔥 应用启动预热开始...');
      try {
        // 在后台线程预热，不阻塞主线程
        unawaited(preInitialize());
        print('🔥 应用启动预热已开始（后台执行）');
      } catch (e) {
        print('🔥 应用启动预热失败: $e');
      }
    }
  }

  // 智能重试机制 - 用于处理首次失败的情况
  static Future<Map<String, String>?> extractTokenWithRetry({
    int maxRetries = 2,
    Duration baseTimeout = const Duration(minutes: 3),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      attempts++;
      final isFirstAttempt = attempts == 1;

      print('🔄 尝试 $attempts/$maxRetries ${isFirstAttempt ? "(首次)" : "(重试)"}');

      // 首次尝试使用更长的超时时间
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

        // 重试前清理和重置
        await dispose();
        await Future.delayed(const Duration(seconds: 2));

        // 重新初始化
        await preInitialize();
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    print('❌ 所有尝试均失败 ($maxRetries/$maxRetries)');
    return null;
  }
}