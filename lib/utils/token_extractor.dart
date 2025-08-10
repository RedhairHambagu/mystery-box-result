import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'webview_helper_improved.dart';

class TokenExtractor {
  static HeadlessInAppWebView? _headlessWebView;
  static InAppWebViewController? _webViewController;

  // 提取wdtoken的核心方法
  static Future<Map<String, String>?> extractToken({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Windows 平台检查 - 允许执行
    if (Platform.isWindows) {
      print('⚠️ Windows 平台运行，可能存在兼容性问题');
    }

    final completer = Completer<Map<String, String>?>();
    Timer? timeoutTimer;

    try {
      print('🚀 开始提取wdtoken');
      print('🎯 目标URL: https://thor.weidian.com/skittles/share.getConfig/*');

      // 确保WebView已预热
      print('⚡ 开始WebView预热...');
      await WebViewHelperImproved.preInitialize();
      // Android 预热后额外等待
      if (Platform.isAndroid) {
        print('⏱️ Android 预热完成，等待系统稳定...');
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // 设置总体超时 - Android 首次使用延长时间
      final isFirstRun = _webViewController == null;
      final actualTimeout = isFirstRun && Platform.isAndroid
          ? const Duration(seconds: 5)  // 首次运行延长超时
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
          userAgent: WebViewHelperImproved.getSimpleUserAgent(),
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

  // 工具方法：从URL提取token
  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['token'] ??
          uri.queryParameters['access_token'] ??
          uri.queryParameters['wd_token'] ??
          uri.queryParameters['wdtoken'];
    } catch (e) {
      print('从URL提取token失败: $e');
      return null;
    }
  }

  // 工具方法：提取下划线参数
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

  // 智能重试机制
  static Future<Map<String, String>?> extractTokenWithRetry({
    int maxRetries = 2,
    Duration baseTimeout = const Duration(minutes: 2),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      attempts++;
      final isFirstAttempt = attempts == 1;

      print('🔄 尝试 $attempts/$maxRetries ${isFirstAttempt ? "(首次)" : "(重试)"}');

      // 首次尝试使用更长的超时时间
      final timeout = isFirstAttempt && Platform.isAndroid
          ? const Duration(seconds: 4)
          : baseTimeout;

      final result = await extractToken(timeout: timeout);

      if (result != null) {
        print('✅ 第 $attempts 次尝试成功');
        return result;
      }

      if (attempts < maxRetries) {
        print('❌ 第 $attempts 次尝试失败，准备重试...');

        // 重试前清理和重置
        await dispose();
        await Future.delayed(const Duration(seconds: 2));

        // 重新初始化WebView环境
        await WebViewHelperImproved.preInitialize();
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    print('❌ 所有尝试均失败 ($maxRetries/$maxRetries)');
    return null;
  }

  // 创建可视化WebView用于获取Token（非headless）
  static Future<Map<String, String>?> createVisualWebViewForToken({
    required Function(InAppWebViewController, Map<String, String>) onTokenExtracted,
    required Function() onCancel,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    try {
      print('🚀 创建可视化WebView获取Token');
      
      // 确保已预初始化
      await WebViewHelperImproved.preInitialize();

      final completer = Completer<Map<String, String>?>();
      Timer? timeoutTimer;

      // 设置超时
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print('⏰ Token提取超时');
          completer.complete(null);
        }
      });

      return completer.future;

    } catch (e) {
      print('❌ 创建可视化WebView失败: $e');
      return null;
    }
  }

  // 获取Token专用的WebView设置
  static InAppWebViewSettings getTokenSettings() {
    return InAppWebViewSettings(
      // 基础功能
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,

      // 启用缓存确保cookie正确传递
      cacheEnabled: true,
      clearCache: false,

      // 性能优化
      hardwareAcceleration: true,
      transparentBackground: false,

      // 平台特定优化
      useHybridComposition: Platform.isAndroid,
      allowsBackForwardNavigationGestures: Platform.isIOS || Platform.isMacOS,

      // 启用调试
      isInspectable: true,
      
      // 允许媒体播放
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,

      // Cookie相关设置
      thirdPartyCookiesEnabled: true,

      // 优化的User Agent
      userAgent: WebViewHelperImproved.getSimpleUserAgent(),
    );
  }

  // 清理资源
  static Future<void> dispose() async {
    try {
      print('开始清理TokenExtractor资源');

      if (_headlessWebView != null) {
        await _headlessWebView!.dispose();
        _headlessWebView = null;
      }

      _webViewController = null;

      print('TokenExtractor资源清理完成');
    } catch (e) {
      print('清理TokenExtractor资源失败: $e');
    }
  }
}