import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';

class LoginWebViewPage extends StatefulWidget {
  final Function(Map<String, String> cookies) onLoginSuccess;
  final VoidCallback onLoginCancel;

  const LoginWebViewPage({
    super.key,
    required this.onLoginSuccess,
    required this.onLoginCancel,
  });

  @override
  State<LoginWebViewPage> createState() => _LoginWebViewPageState();
}

class _LoginWebViewPageState extends State<LoginWebViewPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isWaitingForLogin = false;
  bool _isWebViewReady = false;
  String _currentUrl = '';
  String _statusMessage = '正在初始化...';
  double _loadingProgress = 0.0;
  Timer? _loginCheckTimer;
  Timer? _initTimer;
  bool _hasWebViewCreated = false;
  int _loadAttempts = 0;
  static const int maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    setState(() {
      _statusMessage = '正在初始化WebView环境...';
      _isLoading = true;
    });

    // 设置合理的初始化超时时间
    _initTimer = Timer(const Duration(seconds: 20), () {
      if (!_hasWebViewCreated && mounted) {
        setState(() {
          _statusMessage = 'WebView初始化超时，请重试';
          _isLoading = false;
        });
        _showRetryDialog();
      }
    });
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('加载失败'),
        content: Text(
            Platform.isMacOS
                ? 'macOS平台WebView加载失败。可能的原因：\n\n1. 网络连接问题\n2. WebView组件未正确初始化\n3. 系统WebKit版本问题\n\n建议：\n- 检查网络连接\n- 重启应用\n- 更新系统WebKit'
                : 'WebView加载失败，请检查网络连接或重试'
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
              widget.onLoginCancel();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _retryLoad() {
    if (_loadAttempts >= maxLoadAttempts) {
      _showErrorDialog('加载失败', '已达到最大重试次数，请检查网络连接或重启应用');
      return;
    }

    _loadAttempts++;
    setState(() {
      _statusMessage = '正在重试加载 (第$_loadAttempts次)...';
      _isLoading = true;
      _hasWebViewCreated = false;
      _isWebViewReady = false;
      _loadingProgress = 0.0;
    });

    _initTimer?.cancel();
    _initializeWebView();

    // 强制重建WebView
    setState(() {});
  }

  Future<void> _startLoginDetection() async {
    if (_webViewController == null || !_isWebViewReady) {
      _showErrorDialog('错误', 'WebView未准备就绪，请等待页面完全加载');
      return;
    }

    setState(() {
      _isWaitingForLogin = true;
      _statusMessage = '正在监测登录状态，请在网页中完成登录...';
    });

    _loginCheckTimer?.cancel();
    _loginCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !_isWaitingForLogin) {
        timer.cancel();
        return;
      }

      try {
        final cookies = await _checkLoginStatus();
        if (cookies != null && cookies.isNotEmpty) {
          timer.cancel();
          setState(() {
            _statusMessage = '登录成功！正在保存登录信息...';
            _isWaitingForLogin = false;
          });

          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            widget.onLoginSuccess(cookies);
          }
        }
      } catch (e) {
        print('检查登录状态时出错: $e');
      }
    });

    // 10分钟超时
    Timer(const Duration(minutes: 10), () {
      if (_isWaitingForLogin && mounted) {
        _loginCheckTimer?.cancel();
        setState(() {
          _statusMessage = '登录检测超时，请重试';
          _isWaitingForLogin = false;
        });
      }
    });
  }

  Future<Map<String, String>?> _checkLoginStatus() async {
    try {
      // 检查当前URL
      final currentUrl = await _webViewController!.getUrl();
      if (currentUrl != null) {
        final urlStr = currentUrl.toString();
        print('当前URL: $urlStr');

        // 简化的登录检测逻辑
        if (!urlStr.contains('login') && !urlStr.contains('sso') &&
            urlStr.contains('weidian.com')) {
          final cookies = await _getAllRelevantCookies();
          if (cookies.isNotEmpty) {
            return cookies;
          }
        }
      }

      // 检查cookies
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
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri(domain),
        );
        for (final cookie in cookies) {
          allCookies[cookie.name] = cookie.value;
        }
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

  // 获取优化的WebView设置
  InAppWebViewSettings _getOptimizedSettings() {
    return InAppWebViewSettings(
      // 基础设置
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,

      // 缓存设置 - 关键优化
      cacheEnabled: true,
      clearCache: false,

      // 网络设置
      useShouldOverrideUrlLoading: false,

      // 平台特定优化
      useHybridComposition: Platform.isAndroid,
      allowsBackForwardNavigationGestures: Platform.isIOS || Platform.isMacOS,

      // 减少渲染负担
      hardwareAcceleration: true,
      transparentBackground: false,

      // 简化设置
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,

      // 减少权限请求
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,

      // User Agent
      userAgent: _getSimpleUserAgent(),
    );
  }

  String _getSimpleUserAgent() {
    if (Platform.isMacOS) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    } else if (Platform.isWindows) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    return 'Mozilla/5.0 (compatible) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('微店登录${Platform.isMacOS ? ' (macOS)' : ''}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _loginCheckTimer?.cancel();
            _initTimer?.cancel();
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
              ],
            ),
          ),

          // 操作说明
          if (_isWebViewReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    '操作说明：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 在下方网页中输入微店账号和密码\n'
                        '2. 完成登录后，点击"开始检测登录"按钮\n'
                        '3. 系统将自动检测并保存登录信息',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isWaitingForLogin ? null : _startLoginDetection,
                          icon: _isWaitingForLogin
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.login),
                          label: Text(_isWaitingForLogin ? '检测中...' : '开始检测登录'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _loginCheckTimer?.cancel();
                          _initTimer?.cancel();
                          widget.onLoginCancel();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('取消'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
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
                'macOS平台首次加载可能需要较长时间，请耐心等待',
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

    // 使用 Key 强制重建 WebView
    return InAppWebView(
      key: ValueKey('webview_$_loadAttempts'),
      initialUrlRequest: URLRequest(
        url: WebUri('https://sso.weidian.com/login/index.php'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      initialSettings: _getOptimizedSettings(),

      onWebViewCreated: (controller) {
        _webViewController = controller;
        _hasWebViewCreated = true;
        _initTimer?.cancel();

        if (mounted) {
          setState(() {
            _statusMessage = 'WebView已创建，正在加载页面...';
          });
        }

        print('WebView创建成功 - 平台: ${Platform.operatingSystem}');
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
            _statusMessage = '页面加载完成，可以进行登录操作';
          });
        }
        print('页面加载完成: $_currentUrl');
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
    );
  }

  Color _getStatusColor() {
    if (_isWaitingForLogin) return Colors.green.withOpacity(0.1);
    if (_isWebViewReady) return Colors.blue.withOpacity(0.1);
    return Colors.orange.withOpacity(0.1);
  }

  Color _getStatusTextColor() {
    if (_isWaitingForLogin) return Colors.green[700]!;
    if (_isWebViewReady) return Colors.blue[700]!;
    return Colors.orange[700]!;
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
    } else {
      return const Icon(Icons.warning, color: Colors.orange, size: 16);
    }
  }

  @override
  void dispose() {
    _loginCheckTimer?.cancel();
    _initTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }
}