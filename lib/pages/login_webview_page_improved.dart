import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';
import '../utils/webview_helper_improved.dart';

class LoginWebViewPageImproved extends StatefulWidget {
  final Function(Map<String, String> cookies) onLoginSuccess;
  final VoidCallback onLoginCancel;

  const LoginWebViewPageImproved({
    super.key,
    required this.onLoginSuccess,
    required this.onLoginCancel,
  });

  @override
  State<LoginWebViewPageImproved> createState() => _LoginWebViewPageImprovedState();
}

class _LoginWebViewPageImprovedState extends State<LoginWebViewPageImproved> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isWaitingForLogin = false;
  bool _isWebViewReady = false;
  bool _isPreInitialized = false;
  String _currentUrl = '';
  String _statusMessage = '正在预初始化WebView环境...';
  double _loadingProgress = 0.0;
  Timer? _loginCheckTimer;
  Timer? _preInitTimer;
  bool _hasWebViewCreated = false;
  int _loadAttempts = 0;
  static const int maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    // 跳过预初始化，直接创建WebView
    _isPreInitialized = true;
    _initializeWebView();
  }

  void _initializeWebView() {
    setState(() {
      _statusMessage = '正在加载登录页面...';
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

  // 处理登录成功 - 自动保存并返回
  void _handleLoginSuccess(Map<String, String> cookies) async {
    setState(() {
      _statusMessage = '✅ 登录成功！已保存${cookies.length}个cookie，即将返回主页面...';
      _isWaitingForLogin = false;
    });

    print('检测到登录成功，cookies数量: ${cookies.length}');

    // 延迟2秒让用户看到成功提示
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      widget.onLoginSuccess(cookies);
    }
  }

  // 手动检查登录状态的方法
  Future<void> _manualCheckLogin() async {
    if (_webViewController == null) {
      return;
    }

    setState(() {
      _statusMessage = '正在检查登录状态...';
      _isWaitingForLogin = true;
    });

    try {
      final cookies = await _checkLoginStatus();
      if (cookies != null && cookies.isNotEmpty && cookies.length>3) {
        print('手动检查检测到登录成功');
        _handleLoginSuccess(cookies);
      } else {
        setState(() {
          _statusMessage = '未检测到登录状态，请完成登录后再次点击检查';
          _isWaitingForLogin = false;
        });
      }
    } catch (e) {
      print('手动检查登录状态异常: $e');
      setState(() {
        _statusMessage = '检查登录状态失败: $e';
        _isWaitingForLogin = false;
      });
    }
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('加载失败'),
        content: Text(
          Platform.isMacOS
            ? 'macOS平台WebView加载失败。\n\n可能的解决方案：\n1. 重试加载\n2. 强制继续（可能可用）\n3. 重启应用\n4. 检查网络连接'
            : 'WebView加载失败，但可以尝试继续使用。\n\n选择操作：\n1. 重试加载\n2. 强制继续\n3. 取消操作'
        ),
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
              _forceContinue();
            },
            child: const Text('强制继续'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLoginCancel();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
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

  void _createFallbackWebView() {
    setState(() {
      _statusMessage = '正在创建备用WebView...';
    });
    
    // 即使WebView创建失败，也允许用户继续
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = '备用模式已激活 - 请尝试手动操作';
          _isWebViewReady = true;
        });
      }
    });
  }

  void _retryLoad() {
    if (_loadAttempts >= maxLoadAttempts) {
      _showErrorDialog('重试次数已达上限', '请重启应用或检查系统WebView组件');
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

    // 强制重建WebView
    setState(() {});
  }


  Future<Map<String, String>?> _checkLoginStatus() async {
    try {
      // 检查URL变化
      final currentUrl = await _webViewController!.getUrl();
      if (currentUrl != null) {
        final urlStr = currentUrl.toString();
        
        // 如果URL不再包含登录相关路径，可能已登录
        if (!urlStr.contains('login') && !urlStr.contains('sso') &&
            urlStr.contains('weidian.com')) {
          final cookies = await _getAllRelevantCookies();
          if (cookies.isNotEmpty) {
            return cookies;
          }
        }
      }

      // 检查关键cookies
      final cookies = await _getAllRelevantCookies();
      final hasLoginCookie = cookies.containsKey('wd_guid') ||
          cookies.containsKey('login_token') ||
          cookies.containsKey('session_id') ||
          cookies.keys.any((key) =>
            key.toLowerCase().contains('auth') ||
            key.toLowerCase().contains('token') ||
            key.toLowerCase().contains('session'));

      if (hasLoginCookie && cookies.length > 2) {
        print('检测到登录成功，获取到 ${cookies.length} 个cookies');
        return cookies;
      }

      return null;
    } catch (e) {
      print('检查登录状态失败: $e');
      return null;
    }
  }

  Future<Map<String, String>> _getAllRelevantCookies() async {
    final Map<String, String> allCookies = {};
    final domains = [
      'https://sso.weidian.com',
      'https://weidian.com',
      'https://www.weidian.com',
      'https://h5.weidian.com',
    ];

    for (final domain in domains) {
      try {
        final cookies = await WebViewHelperImproved.getCookies(domain);
        allCookies.addAll(cookies);
      } catch (e) {
        print('获取 $domain cookies 失败: $e');
      }
    }

    return allCookies;
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('微店登录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _loginCheckTimer?.cancel();
            _preInitTimer?.cancel();
            widget.onLoginCancel();
          },
        ),
        actions: [
          if (_isWebViewReady)
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
          if (_isWebViewReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 检查登录状态按钮
                  if (!_isWaitingForLogin)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _manualCheckLogin,
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text('下方登录后，点此处检查登录状态'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '检测中...',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // 取消按钮
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _loginCheckTimer?.cancel();
                        _preInitTimer?.cancel();
                        widget.onLoginCancel();
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消登录'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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
            if (Platform.isMacOS) ...[
              const SizedBox(height: 8),
              const Text(
                'macOS平台已优化初始化流程，请耐心等待',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
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
      key: ValueKey('webview_improved_$_loadAttempts'),
      initialUrlRequest: URLRequest(
        url: WebUri('https://sso.weidian.com/login/index.php'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      initialSettings: WebViewHelperImproved.getOptimizedSettings(),

      onWebViewCreated: (controller) {
        _webViewController = controller;
        _hasWebViewCreated = true;

        if (mounted) {
          setState(() {
            _statusMessage = 'WebView已创建，正在加载页面...';
          });
        }

        print('改进版WebView创建成功 - 平台: ${Platform.operatingSystem}');
      },

      onLoadStart: (controller, url) {
        if (mounted) {
          setState(() {
            _currentUrl = url?.toString() ?? '';
            _loadingProgress = 0.0;
            _statusMessage = '正在加载登录页面...';
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

      onLoadStop: (controller, url) {
        if (mounted) {
          setState(() {
            _currentUrl = url?.toString() ?? '';
            _loadingProgress = 1.0;
            _isLoading = false;
            _isWebViewReady = true;
            _statusMessage = '页面加载完成，点击下方 检查登录状态';
          });
        }
        print('页面加载完成: $_currentUrl');
        
        // 页面加载完成，等待用户手动检查登录状态
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

      // 监听 URL 变化，快速检测登录状态
      onUpdateVisitedHistory: (controller, url, androidIsReload) {
        final urlString = url?.toString() ?? '';
        print('URL变化: $urlString');
        
        // 移除自动检测逻辑，改为用户手动确认
      },
    );
  }

  Color _getStatusColor() {
    if (_isWaitingForLogin) return Colors.green.withOpacity(0.1);
    if (_isWebViewReady) return Colors.blue.withOpacity(0.1);
    if (_isPreInitialized) return Colors.orange.withOpacity(0.1);
    return Colors.grey.withOpacity(0.1);
  }

  Color _getStatusTextColor() {
    if (_isWaitingForLogin) return Colors.green[700]!;
    if (_isWebViewReady) return Colors.blue[700]!;
    if (_isPreInitialized) return Colors.orange[700]!;
    return Colors.grey[700]!;
  }

  Widget _getStatusIcon() {
    if (_isLoading || _isWaitingForLogin) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_isWebViewReady) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    } else if (_isPreInitialized) {
      return const Icon(Icons.pending, color: Colors.orange, size: 16);
    } else {
      return const Icon(Icons.hourglass_empty, color: Colors.grey, size: 16);
    }
  }

  @override
  void dispose() {
    _loginCheckTimer?.cancel();
    _preInitTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }
}