import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';
import '../utils/webview_helper_improved.dart';
import '../utils/token_extractor.dart';
import '../services/auth_service.dart';

class TokenWebViewPage extends StatefulWidget {
  final Function(Map<String, String> tokenData) onTokenExtracted;
  final VoidCallback onCancel;

  const TokenWebViewPage({
    super.key,
    required this.onTokenExtracted,
    required this.onCancel,
  });

  @override
  State<TokenWebViewPage> createState() => _TokenWebViewPageState();
}

class _TokenWebViewPageState extends State<TokenWebViewPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isWebViewReady = false;
  bool _hasTokenExtracted = false;
  String _currentUrl = '';
  String _statusMessage = '正在加载token获取页面...';
  double _loadingProgress = 0.0;
  Timer? _timeoutTimer;
  bool _hasWebViewCreated = false;
  int _loadAttempts = 0;
  static const int maxLoadAttempts = 3;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _setTokenExtractionTimeout();
  }

  void _initializeWebView() {
    setState(() {
      _statusMessage = '正在加载token获取页面...';
      _isLoading = true;
    });

    // 简单的超时机制，5秒后显示跳过选项
    Timer(const Duration(seconds: 5), () {
      if (!_hasWebViewCreated && mounted) {
        setState(() {
          _statusMessage = 'WebView加载较慢，点击"强制继续"尝试使用';
          _isLoading = false;
        });
      }
    });
  }

  void _setTokenExtractionTimeout() {
    // 设置总体超时时间为2分钟
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      if (!_hasTokenExtracted && mounted) {
        setState(() {
          _statusMessage = '⏰ Token获取超时，请重试或检查网络连接';
        });
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Token获取超时'),
        content: const Text('Token获取过程超时，可能由于网络问题或页面加载缓慢。\n\n选择操作：'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryLoad();
            },
            child: const Text('重试'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCancel();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _retryLoad() {
    if (_loadAttempts >= maxLoadAttempts) {
      _showErrorDialog('重试次数已达上限', '请返回主页面重新尝试或检查网络连接');
      return;
    }

    _loadAttempts++;
    setState(() {
      _statusMessage = '正在重试 (第$_loadAttempts次)...';
      _isLoading = true;
      _hasWebViewCreated = false;
      _isWebViewReady = false;
      _loadingProgress = 0.0;
    });

    // 重新设置超时
    _timeoutTimer?.cancel();
    _setTokenExtractionTimeout();

    // 强制重建WebView
    setState(() {});
  }

  void _forceContinue() {
    setState(() {
      _statusMessage = '强制继续模式 - 直接创建基础WebView';
      _isLoading = false;
      _hasWebViewCreated = true;
      _isWebViewReady = true;
    });
    
    print('用户选择强制继续，跳过复杂的初始化流程');
  }

  // 处理token获取成功
  void _handleTokenExtracted(Map<String, String> tokenData) async {
    if (_hasTokenExtracted) return; // 防止重复处理

    _hasTokenExtracted = true;
    _timeoutTimer?.cancel();

    setState(() {
      _statusMessage = '✅ Token获取成功！正在保存...';
    });

    try {
      // 保存token到AuthService
      await _authService.saveWdTokenAndParams(tokenData);
      print('Token已保存到AuthService: ${tokenData['wdtoken']}...');
      
      setState(() {
        _statusMessage = '✅ Token获取成功并已保存！即将返回主页面...';
      });

      // 延迟2秒让用户看到成功提示
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        widget.onTokenExtracted(tokenData);
      }
    } catch (e) {
      print('保存Token失败: $e');
      setState(() {
        _statusMessage = '❌ Token保存失败: $e';
      });
    }
  }

  // 设置cookies为WebView
  Future<void> _setCookiesForWebView() async {
    try {
      final cookieString = await _authService.getCookie();
      if (cookieString != null && cookieString.isNotEmpty) {
        // 解析cookie字符串为Map
        final cookieMap = <String, String>{};
        final cookies = cookieString.split('; ');
        for (final cookie in cookies) {
          final parts = cookie.split('=');
          if (parts.length == 2) {
            cookieMap[parts[0].trim()] = parts[1].trim();
          }
        }
        
        // 为相关域名设置cookies
        final domains = [
          'https://h5.weidian.com',
          'https://weidian.com',
          'https://www.weidian.com',
          'https://sso.weidian.com',
          'https://thor.weidian.com',
        ];
        
        for (final domain in domains) {
          await WebViewHelperImproved.setCookies(domain, cookieMap);
        }
        
        print('✅ 已为token获取页面设置cookies');
      }
    } catch (e) {
      print('❌ 设置cookies失败: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCancel();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // Windows平台额外的token检测方法
  void _checkUrlForTokenWindows(String url) {
    // 检查各种可能包含token的URL模式
    final tokenPatterns = [
      'wdtoken=',
      'token=',
      'access_token=',
      'wd_token=',
    ];
    
    for (final pattern in tokenPatterns) {
      if (url.contains(pattern)) {
        print('🪟 [Windows] 检测到token模式: $pattern in $url');
        try {
          final uri = Uri.parse(url);
          final token = uri.queryParameters['wdtoken'] ??
                       uri.queryParameters['token'] ??
                       uri.queryParameters['access_token'] ??
                       uri.queryParameters['wd_token'];
          
          if (token != null && token.isNotEmpty && !_hasTokenExtracted) {
            print('🪟 [Windows] 通过URL模式检测到token: $token');
            
            final underscoreParams = TokenExtractor.extractUnderscoreParams(url);
            final result = <String, String>{
              'wdtoken': token,
              'token': token,
              'foundUrl': url,
              'source': 'TokenWebViewPage_WindowsCheck',
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              'platform': Platform.operatingSystem,
            };
            
            result.addAll(underscoreParams);
            _handleTokenExtracted(result);
            return;
          }
        } catch (e) {
          print('🪟 [Windows] URL解析异常: $e');
        }
      }
    }
    
    // 检查微店相关的API调用
    if (url.contains('weidian.com') && (url.contains('api') || url.contains('ajax'))) {
      print('🪟 [Windows] 检测到微店API调用: $url');
    }
  }

  // Windows平台注入JavaScript监听器
  void _injectWindowsTokenListener(InAppWebViewController controller) {
    try {
      final jsCode = '''
        (function() {
          console.log('🪟 [Windows] JavaScript token监听器已注入');
          
          // 重写XMLHttpRequest
          const originalXHR = window.XMLHttpRequest;
          window.XMLHttpRequest = function() {
            const xhr = new originalXHR();
            const originalOpen = xhr.open;
            const originalSend = xhr.send;
            
            xhr.open = function(method, url, async, user, password) {
              if (url && (url.includes('thor.weidian.com') || url.includes('wdtoken'))) {
                console.log('🪟 [Windows] XHR请求:', url);
                window.flutter_inappwebview.callHandler('onWindowsTokenFound', url);
              }
              return originalOpen.apply(this, arguments);
            };
            
            return xhr;
          };
          
          // 重写fetch
          const originalFetch = window.fetch;
          window.fetch = function(url, options) {
            if (url && (url.includes('thor.weidian.com') || url.includes('wdtoken'))) {
              console.log('🪟 [Windows] Fetch请求:', url);
              window.flutter_inappwebview.callHandler('onWindowsTokenFound', url);
            }
            return originalFetch.apply(this, arguments);
          };
          
          console.log('🪟 [Windows] 网络请求监听器设置完成');
        })();
      ''';
      
      controller.evaluateJavascript(source: jsCode);
      
      // 添加JavaScript处理器
      controller.addJavaScriptHandler(
        handlerName: 'onWindowsTokenFound',
        callback: (args) {
          if (args.isNotEmpty) {
            final url = args[0].toString();
            print('🪟 [Windows] JavaScript检测到token URL: $url');
            _checkUrlForTokenWindows(url);
          }
        },
      );
      
    } catch (e) {
      print('🪟 [Windows] JavaScript注入失败: $e');
    }
  }

  // Windows平台定期轮询检查token
  Timer? _windowsPollingTimer;
  
  void _startWindowsTokenPolling(InAppWebViewController controller) {
    print('🪟 [Windows] 启动token轮询检查...');
    
    _windowsPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_hasTokenExtracted || !mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // 检查当前URL是否包含token
        final currentUrl = await controller.getUrl();
        if (currentUrl != null) {
          final urlString = currentUrl.toString();
          if (urlString.contains('wdtoken=')) {
            print('🪟 [Windows] 轮询检查发现token URL: $urlString');
            _checkUrlForTokenWindows(urlString);
          }
        }
        
        // 执行JavaScript检查localStorage和sessionStorage
        final jsResult = await controller.evaluateJavascript(source: '''
          (function() {
            try {
              var result = {
                localStorage: {},
                sessionStorage: {},
                cookies: document.cookie,
                currentUrl: window.location.href
              };
              
              // 检查localStorage
              for (var i = 0; i < localStorage.length; i++) {
                var key = localStorage.key(i);
                if (key && (key.includes('token') || key.includes('wd'))) {
                  result.localStorage[key] = localStorage.getItem(key);
                }
              }
              
              // 检查sessionStorage
              for (var i = 0; i < sessionStorage.length; i++) {
                var key = sessionStorage.key(i);
                if (key && (key.includes('token') || key.includes('wd'))) {
                  result.sessionStorage[key] = sessionStorage.getItem(key);
                }
              }
              
              return JSON.stringify(result);
            } catch (e) {
              return JSON.stringify({error: e.message});
            }
          })();
        ''');
        
        if (jsResult != null) {
          print('🪟 [Windows] 轮询检查结果: $jsResult');
        }
        
      } catch (e) {
        print('🪟 [Windows] 轮询检查异常: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('获取Token'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _timeoutTimer?.cancel();
            widget.onCancel();
          },
        ),
        actions: [
          if (_isWebViewReady && !_hasTokenExtracted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _webViewController?.reload();
              },
            ),
          if (!_hasWebViewCreated && _loadAttempts < maxLoadAttempts)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _retryLoad,
              tooltip: '重试加载',
            ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getStatusIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _getStatusTextColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_currentUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前页面: $_currentUrl',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_loadingProgress > 0 && _loadingProgress < 1) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _loadingProgress),
                ],
                // 添加强制继续按钮
                if (!_hasWebViewCreated && !_isLoading) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _forceContinue,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('强制继续'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _retryLoad,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('重试'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 简化的按钮区域
          if (_isWebViewReady && !_hasTokenExtracted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: const Text(
                        '页面已加载，正在监听token请求...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 取消按钮
                  ElevatedButton.icon(
                    onPressed: () {
                      _timeoutTimer?.cancel();
                      widget.onCancel();
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('取消'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          // WebView区域
          Expanded(
            child: _buildWebViewArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebViewArea() {
    if (_isLoading && !_hasWebViewCreated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage),
            if (_loadAttempts > 0 && _loadAttempts < maxLoadAttempts) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryLoad,
                child: Text('重试 ($_loadAttempts/$maxLoadAttempts)'),
              ),
            ],
          ],
        ),
      );
    }

    // 使用Key强制重建WebView
    return InAppWebView(
      key: ValueKey('token_webview_$_loadAttempts'),
      initialUrlRequest: URLRequest(
        url: WebUri('https://h5.weidian.com/m/mystery-box/list.html#/'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      initialSettings: TokenExtractor.getTokenSettings(),

      onWebViewCreated: (controller) async {
        _webViewController = controller;
        _hasWebViewCreated = true;

        // 设置cookies
        await _setCookiesForWebView();

        if (mounted) {
          setState(() {
            _statusMessage = 'WebView已创建，正在加载mystery-box页面...';
          });
        }

        print('Token WebView创建成功 - 平台: ${Platform.operatingSystem}');
      },

      onLoadStart: (controller, url) {
        if (mounted) {
          setState(() {
            _currentUrl = url?.toString() ?? '';
            _loadingProgress = 0.0;
            _statusMessage = '正在加载mystery-box页面...';
          });
        }
        print('开始加载: $_currentUrl');
      },

      onProgressChanged: (controller, progress) {
        if (mounted) {
          setState(() {
            _loadingProgress = progress / 100.0;
          });
        }
      },

      onLoadStop: (controller, url) async {
        if (mounted) {
          setState(() {
            _currentUrl = url?.toString() ?? '';
            _loadingProgress = 1.0;
            _isLoading = false;
            _isWebViewReady = true;
            _statusMessage = '✅ 盲盒记录出现后关闭即可';
          });
        }
        print('页面加载完成: $_currentUrl');
        
        // Windows平台特定：注入JavaScript监听网络请求
        if (Platform.isWindows && !_hasTokenExtracted) {
          print('🪟 [Windows] 页面加载完成，注入token监听JavaScript...');
          _injectWindowsTokenListener(controller);
          
          // 启动定时器定期检查token
          _startWindowsTokenPolling(controller);
        }
      },

      onReceivedError: (controller, request, error) {
        print('WebView加载错误: ${error.description}');
        if (mounted) {
          setState(() {
            _statusMessage = '页面加载错误: ${error.description}';
            _isLoading = false;
          });
        }
      },

      onReceivedHttpError: (controller, request, errorResponse) {
        print('HTTP错误: ${errorResponse.statusCode}');
        if (mounted) {
          setState(() {
            _statusMessage = 'HTTP错误: ${errorResponse.statusCode}';
            _isLoading = false;
          });
        }
      },

      // 监听资源加载，捕获token请求
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();
        
        // Windows平台增强调试输出
        if (Platform.isWindows) {
          if (url.contains('thor.weidian.com') || url.contains('wdtoken') || url.contains('share.getConfig')) {
            print('🪟 [Windows] 资源加载: $url');
          }
        }
        
        // 检查是否是目标URL
        if (url.contains('https://thor.weidian.com/skittles/share.getConfig')) {
          print('🎯 发现目标URL: $url');
          print('🎯 [${Platform.operatingSystem}] 开始解析token...');
          
          if (url.contains('wdtoken=')) {
            print('🔑 发现wdtoken参数');
            
            try {
              final uri = Uri.parse(url);
              final wdtoken = uri.queryParameters['wdtoken'];
              
              if (wdtoken != null && wdtoken.isNotEmpty && !_hasTokenExtracted) {
                // 提取所有以"_"开头的参数
                final underscoreParams = TokenExtractor.extractUnderscoreParams(url);
                
                // 遵循CLAUDE.md指令，不使用substring截断
                print('✅ 成功获取wdtoken: $wdtoken (长度: ${wdtoken.length})');
                print('📊 下划线参数: $underscoreParams');
                print('🎉 [${Platform.operatingSystem}] Token提取成功！');
                
                final result = <String, String>{
                  'wdtoken': wdtoken,
                  'token': wdtoken,
                  'foundUrl': url,
                  'source': 'TokenWebViewPage_onLoadResource',
                  'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
                  'platform': Platform.operatingSystem,
                };
                
                result.addAll(underscoreParams);
                
                // 处理token获取成功
                _handleTokenExtracted(result);
              }
            } catch (e) {
              print('❌ [${Platform.operatingSystem}] URL解析错误: $e');
            }
          } else {
            print('⚠️ [${Platform.operatingSystem}] 目标URL不包含wdtoken参数: $url');
          }
        }
        
        // Windows平台额外的token检测方法
        if (Platform.isWindows && !_hasTokenExtracted) {
          _checkUrlForTokenWindows(url);
        }
      },
    );
  }

  Color _getStatusColor() {
    if (_hasTokenExtracted) return Colors.green.withOpacity(0.1);
    if (_isWebViewReady) return Colors.blue.withOpacity(0.1);
    return Colors.grey.withOpacity(0.1);
  }

  Color _getStatusTextColor() {
    if (_hasTokenExtracted) return Colors.green[700]!;
    if (_isWebViewReady) return Colors.blue[700]!;
    return Colors.grey[700]!;
  }

  Widget _getStatusIcon() {
    if (_isLoading || _hasTokenExtracted) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_isWebViewReady) {
      return const Icon(Icons.search, color: Colors.blue, size: 16);
    } else {
      return const Icon(Icons.hourglass_empty, color: Colors.grey, size: 16);
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _windowsPollingTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }
}