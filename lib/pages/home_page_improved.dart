import 'dart:convert' show JsonEncoder;
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/mystery_box_group.dart';
import '../models/mystery_box_record.dart';
import '../services/auth_service.dart';
import '../services/mystery_box_service.dart';
import '../utils/webview_helper_improved.dart';
import '../widgets/mystery_box_group_widget.dart';
import '../widgets/login_status_widget.dart';
import 'login_webview_page_improved.dart';
import 'token_webview_page.dart';

class HomePageImproved extends StatefulWidget {
  const HomePageImproved({super.key});

  @override
  State<HomePageImproved> createState() => _HomePageImprovedState();
}

// 莫兰迪绿色系主题颜色
class MorandiGreenTheme {
  static const Color primary = Color(0xFF7D9D8E);      // 主绿色
  static const Color primaryLight = Color(0xFF9BB3A8);  // 浅绿色
  static const Color primaryDark = Color(0xFF5F7A6E);   // 深绿色
  static const Color accent = Color(0xFF8FA89C);        // 强调色
  static const Color background = Color(0xFFF2F5F3);    // 背景色
  static const Color surface = Color(0xFFE8EDE9);       // 表面色
  static const Color surfaceVariant = Color(0xFFDDE4DF); // 表面变体色
  
  // 新增：卡片专用颜色，与背景有更好的对比度
  static const Color cardPrimary = Color(0xFF6B8A7A);     // 深绿色卡片
  static const Color cardSecondary = Color(0xFF8B9D8F);   // 中绿色卡片
  static const Color cardAccent = Color(0xFFA3B5A7);      // 浅绿色卡片
  static const Color cardWarning = Color(0xFFB8956B);     // 暖黄色卡片
}

class _HomePageImprovedState extends State<HomePageImproved> {
  final AuthService _authService = AuthService();
  final MysteryBoxService _mysteryBoxService = MysteryBoxService();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _canFetchItems = false;
  bool _isWebViewSupported = false;
  bool _isInitializing = true;
  bool _isPreInitialized = false;
  bool _hasToken = false;
  bool _isGettingToken = false;
  int _currentPage = 0;
  List<MysteryBoxRecord> _allRecords = [];
  List<MysteryBoxGroup> _mysteryBoxGroups = [];
  String _statusMessage = '';
  String _platformInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  bool _showDebugPanel = false;
  Map<String, dynamic>? _debugInfo;

  void _toggleDebugPanel() {
    setState(() {
      _showDebugPanel = !_showDebugPanel;
    });
  }

  Future<void> _runFullDiagnosis() async {
    setState(() {
      _statusMessage = '正在运行系统诊断...';
    });

    try {
      final diagnosis = await WebViewHelperImproved.getDebugInfo();

      setState(() {
        _debugInfo = diagnosis;
        _statusMessage = '✅ 诊断完成，请查看调试面板详细信息';
      });

      print('=== 系统诊断结果 ===');
      print(const JsonEncoder.withIndent('  ').convert(diagnosis));
      print('=== 诊断结束 ===');

    } catch (e) {
      setState(() {
        _statusMessage = '❌ 诊断过程中出现错误: $e';
      });
      print('诊断过程异常: $e');
    }
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = '正在初始化应用...';
    });

    await _initializeWebView();
    // 移除自动检查登录状态，改为用户手动检查

    setState(() {
      _isInitializing = false;
      _statusMessage = '✅ 应用初始化完成，可以开始使用';
    });
  }

  Future<void> _initializeWebView() async {
    try {
      setState(() {
        _statusMessage = '正在预初始化WebView环境...\n如果加载较慢，可以点击"跳过初始化"直接使用';
      });

      // 使用改进的预初始化方法，带有超时控制
      final initFuture = WebViewHelperImproved.preInitialize();
      final timeoutFuture = Future.delayed(const Duration(seconds: 5));
      
      final result = await Future.any([
        initFuture.then((value) => {'success': true, 'supported': value}),
        timeoutFuture.then((_) => {'success': false, 'timeout': true}),
      ]);

      final platformInfo = WebViewHelperImproved.getPlatformInfo();
      
      bool isSupported = true; // 默认假设支持
      if (result['success'] == true) {
        isSupported = result['supported'] as bool;
      } else {
        // 超时情况，假设支持但给出提示
        print('WebView预初始化超时，假设支持');
      }

      setState(() {
        _isWebViewSupported = isSupported;
        _isPreInitialized = isSupported;
        _platformInfo = platformInfo;
        
        if (result['timeout'] == true) {
          _statusMessage = '⚠️ 预初始化超时，但可以正常使用\n$platformInfo\n'
              '建议：直接进行登录操作';
        } else if (!isSupported) {
          _statusMessage = '⚠️ WebView不可用 - $platformInfo\n请确保系统支持WebView功能';
        } else {
          _statusMessage = Platform.isMacOS
              ? '✅ macOS WebView预初始化完成 - $platformInfo'
              : '✅ WebView环境预初始化完成 - $platformInfo';
        }
      });

      print('WebView预初始化完成 - 支持状态: $isSupported, 平台: $platformInfo');

    } catch (e) {
      setState(() {
        _isWebViewSupported = true; // 假设支持，让用户尝试
        _isPreInitialized = true;
        _statusMessage = '⚠️ 预初始化异常，但可以尝试使用: $e\n建议直接进行登录操作';
      });
      print('WebView预初始化失败: $e');
    }
  }

  void _skipInitialization() {
    setState(() {
      _isInitializing = false;
      _isWebViewSupported = true;
      _isPreInitialized = true;
      _statusMessage = '✅ 已跳过预初始化，可以直接使用\n${WebViewHelperImproved.getPlatformInfo()}';
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (!isLoggedIn) {
        setState(() {
          _isLoggedIn = false;
          _hasToken = false;
          _canFetchItems = false;
          _statusMessage = '未登录状态';
        });
        return;
      }
      
      // 验证Cookie是否有效
      final isValid = await _authService.validateCookie();

      setState(() {
        _isLoggedIn = isValid;
        if (!isValid) {
          _hasToken = false;
          _canFetchItems = false;
          _statusMessage = '登录已过期，请重新登录';
          print('登录状态检查：Cookie无效');
        } else {
          _statusMessage = '已登录状态';
          print('登录状态检查：登录有效');
        }
      });
    } catch (e) {
      print('检查登录状态失败: $e');
      setState(() {
        _isLoggedIn = false;
        _hasToken = false;
        _canFetchItems = false;
        _statusMessage = '检查登录状态失败';
      });
    }
  }

  Future<void> _openLoginPage() async {
    setState(() {
      _statusMessage = '正在打开登录页面...';
    });

    try {
      // 即使WebView支持状态不确定，也允许用户尝试
      setState(() {
        _statusMessage = _isWebViewSupported 
            ? '正在启动登录界面...'
            : '⚠️ WebView状态不确定，但允许尝试登录...';
      });

      final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (context) => LoginWebViewPageImproved(
            onLoginSuccess: (cookies) {
              print('登录成功回调被调用，cookies数量: ${cookies.length}');
              Navigator.of(context).pop(cookies);
            },
            onLoginCancel: () {
              print('登录取消回调被调用');
              Navigator.of(context).pop();
            },
          ),
          settings: const RouteSettings(name: '/login_improved'),
          fullscreenDialog: true,
        ),
      );

      // 处理登录结果
      if (result != null || (result == null && mounted)) {
        print('登录流程完成，Cookie和Token已在登录页面中保存到AuthService');

        setState(() {
          _statusMessage = '✅ 登录成功！Cookie和Token已自动获取\n'
              '- 登录凭据已安全保存到本地\n'
              '- Token已在登录过程中自动捕获';
        });

        // 不再重复保存Cookie，因为已在LoginWebViewPageImproved中保存
        print('跳过重复保存，Cookie和Token已在登录流程中处理完成');

        // 检查是否在登录过程中已自动获取Token
        final wdToken = await _authService.getWdToken();
        final hasAutoToken = wdToken != null && wdToken.isNotEmpty;
        
        setState(() {
          _isLoggedIn = true;
          _isWebViewSupported = true; // 如果登录成功，说明WebView是可用的
          
          if (hasAutoToken) {
            _hasToken = true;
            _canFetchItems = true;
            _statusMessage = '🎉 登录成功并自动获取Token！\n'
                '- 登录凭据已安全保存\n'
                '- Token已自动获取并保存\n'
                '- 现在可以直接获取盲盒记录！';
          } else {
            _hasToken = false;
            _canFetchItems = false;
            _statusMessage = '✅ 登录成功！\n'
                '- 登录凭据已安全保存\n'
                '- 请点击"②获取Token"按钮获取Token\n'
                '- 或重试登录过程以自动获取Token';
          }
        });

        final message = hasAutoToken
            ? '登录成功并自动获取Token！可以直接获取盲盒记录'
            : '登录成功，登录凭据已安全保存';
        _showSuccessSnackBar(message);
        
        // 延迟1秒后更新状态消息
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              if (hasAutoToken) {
                _statusMessage = '🎉 登录成功并自动获取Token！现在可以直接获取盲盒记录';
              } else {
                _statusMessage = '✅ 登录成功！请点击"②获取Token"获取Token信息';
              }
            });
          }
        });
      } else {
        setState(() {
          _statusMessage = result == null ? '登录已取消' : '登录失败，未获取到有效信息';
        });

        if (result == null) {
          print('用户取消了登录');
        } else {
          print('登录失败，结果为空');
          // 不显示错误，给用户重试机会
          setState(() {
            _statusMessage = '登录未成功，可以重试或检查网络连接';
          });
        }
      }
    } catch (e) {
      print('登录过程异常: $e');
      setState(() {
        _statusMessage = '⚠️ 登录过程中出现问题，但可以重试: $e';
      });
      // 不阻止用户重试
    }
  }




  // 获取Token的方法
  Future<void> _extractToken() async {
    if (!_isLoggedIn) {
      _showErrorSnackBar('请先登录');
      return;
    }

    setState(() {
      _statusMessage = '正在打开token获取页面...';
    });

    try {
      // 打开token获取页面，类似登录页面
      final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (context) => TokenWebViewPage(
            onTokenExtracted: (tokenData) {
              print('Token获取成功回调被调用，Token长度: ${tokenData['wdtoken']?.length ?? 0}');
              Navigator.of(context).pop(tokenData);
            },
            onCancel: () {
              print('Token获取取消回调被调用');
              Navigator.of(context).pop();
            },
          ),
          settings: const RouteSettings(name: '/token_extraction'),
          fullscreenDialog: true,
        ),
      );

      // 处理token获取结果
      if (result != null && result.containsKey('wdtoken')) {
        final token = result['wdtoken']!;
        final tokenLength = token.length;
        
        // 保存token到AuthService
        await _authService.saveWdTokenAndParams(result);
        
        setState(() {
          _hasToken = true;
          _canFetchItems = true;
          _statusMessage = '✅ 成功获取Token！\n'
              '- Token长度: ${tokenLength}字符\n'
              '- 来源: ${result['source'] ?? 'web_page'}\n'
              '现在可以获取盲盒记录';
        });
        
        _showSuccessSnackBar('Token获取成功，长度: ${tokenLength}字符');
        print('✅ Token获取成功: ${token.substring(0, token.length.clamp(0, 20))}...');
        
      } else {
        setState(() {
          _statusMessage = result == null ? 'Token获取已取消' : '❌ 未能获取到有效Token';
        });
        
        if (result == null) {
          print('用户取消了Token获取');
        } else {
          _showErrorSnackBar('Token获取失败，请重试');
        }
      }
      
    } catch (e) {
      print('Token获取过程异常: $e');
      setState(() {
        _statusMessage = '❌ Token获取过程中出现错误: $e';
      });
      _showErrorSnackBar('Token获取失败: $e');
    }
  }

  // 新增：为盲盒页面设置cookies的方法
  Future<void> _setCookiesForMysteryBox() async {
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
        
        // 为所有相关域名设置cookies
        final domains = [
          'https://h5.weidian.com',
          'https://weidian.com',
          'https://www.weidian.com',
          'https://sso.weidian.com',
          'https://thor.weidian.com',
        ];
        
        for (final domain in domains) {
          await WebViewHelperImproved.setCookies(domain, cookieMap);
          print('已为域名 $domain 设置 ${cookieMap.length} 个cookies');
        }
        
        print('✅ 成功为盲盒页面设置cookies');
      } else {
        print('⚠️ 没有找到已保存的cookies');
      }
    } catch (e) {
      print('❌ 设置盲盒页面cookies失败: $e');
    }
  }

  Future<void> _fetchMysteryBoxRecords() async {
    if (!_hasToken || !_canFetchItems) {
      _showErrorSnackBar('请先获取Token信息');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '正在获取第${_currentPage + 1}页数据...';
    });

    try {
      final newRecords = await _mysteryBoxService.fetchMysteryBoxRecords(_currentPage);

      setState(() {
        _allRecords.addAll(newRecords);
        _currentPage++;
      });

      await _processRecordsIntoGroups();

      setState(() {
        _statusMessage = '✅ 成功获取${newRecords.length}条新记录\n'
            '当前总计: ${_allRecords.length}条记录\n'
            '分为: ${_mysteryBoxGroups.length}个盲盒组';
      });

      _showSuccessSnackBar('成功获取${newRecords.length}条新记录');

    } catch (e) {
      print('获取盲盒记录失败: $e');
      
      // 检查是否是token相关错误，如果是则自动重新获取token
      String errorStr = e.toString().toLowerCase();
      bool isTokenError = errorStr.contains('认证') || 
                         errorStr.contains('token') || 
                         errorStr.contains('401') || 
                         errorStr.contains('403') ||
                         errorStr.contains('未找到认证信息');
      
      if (isTokenError && _isLoggedIn) {
        setState(() {
          _statusMessage = '❌ Token失效，正在自动重新获取...';
        });
        
        try {
          // 重新获取token
          await _extractToken();
          
          // 如果token获取成功，重试获取盲盒记录
          if (_hasToken) {
            setState(() {
              _statusMessage = '✅ Token重新获取成功，正在重试获取盲盒记录...';
            });
            
            final newRecords = await _mysteryBoxService.fetchMysteryBoxRecords(_currentPage);
            
            setState(() {
              _allRecords.addAll(newRecords);
              _currentPage++;
            });
            
            await _processRecordsIntoGroups();
            
            setState(() {
              _statusMessage = '✅ 成功获取${newRecords.length}条新记录\n'
                  '当前总计: ${_allRecords.length}条记录\n'
                  '分为: ${_mysteryBoxGroups.length}个盲盒组';
            });
            
            _showSuccessSnackBar('Token重新获取成功，获得${newRecords.length}条记录');
            return;
          }
        } catch (retryError) {
          print('重新获取token失败: $retryError');
        }
      }
      
      _showErrorSnackBar('获取盲盒记录失败: $e');
      setState(() {
        _statusMessage = '❌ 获取数据失败: $e${isTokenError ? '\n建议手动重新获取Token' : ''}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processRecordsIntoGroups() async {
    setState(() {
      _statusMessage = '正在处理数据，生成盲盒组...';
    });

    final Map<String, List<MysteryBoxRecord>> groupedRecords = {};

    for (final record in _allRecords) {
      if (!groupedRecords.containsKey(record.itemId)) {
        groupedRecords[record.itemId] = [];
      }
      groupedRecords[record.itemId]!.add(record);
    }

    final List<MysteryBoxGroup> groups = [];
    int processedGroups = 0;

    for (final entry in groupedRecords.entries) {
      final itemId = entry.key;
      final records = entry.value;

      if (records.isNotEmpty) {
        try {
          setState(() {
            _statusMessage = '正在处理盲盒组 ${++processedGroups}/${groupedRecords.length}...';
          });

          final boxInfo = await _mysteryBoxService.fetchBoxInfo(itemId, records.first.orderId);
          final completeList = await _mysteryBoxService.fetchCompleteItemList(boxInfo['auth']!);

          final group = MysteryBoxGroup.fromRecords(
            itemId,
            boxInfo['name']!,
            boxInfo['auth']!,
            records,
            completeList,
          );

          groups.add(group);
        } catch (e) {
          print('处理群组 $itemId 时出错: $e');
        }
      }
    }

    setState(() {
      _mysteryBoxGroups = groups;
    });
  }

  Future<void> _resetData() async {
    setState(() {
      _allRecords.clear();
      _mysteryBoxGroups.clear();
      _currentPage = 0;
      _hasToken = false;
      _canFetchItems = false;
      _statusMessage = '✅ 数据已重置，请重新获取Token后开始';
    });

    // 清除AuthService中的token数据
    try {
      await _authService.clearWdToken();
      print('✅ Token数据已清除');
    } catch (e) {
      print('清除Token数据时出错: $e');
    }

    _showSuccessSnackBar('数据已重置');
  }

  Future<void> _clearWebViewData() async {
    setState(() {
      _statusMessage = '正在清理WebView数据...';
    });

    try {
      await WebViewHelperImproved.clearAllCookies();
      await WebViewHelperImproved.dispose();

      if (Platform.isMacOS) {
        await Future.delayed(const Duration(seconds: 2));
      }

      setState(() {
        _statusMessage = '✅ WebView数据已清理';
      });
      _showSuccessSnackBar('WebView数据已清理');
    } catch (e) {
      _showErrorSnackBar('清理WebView数据失败: $e');
      setState(() {
        _statusMessage = '❌ 清理失败: $e';
      });
    }
  }

  Widget _buildDebugPanel() {
    if (!_showDebugPanel) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MorandiGreenTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MorandiGreenTheme.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: MorandiGreenTheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🔧 调试面板',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleDebugPanel,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _runFullDiagnosis,
                icon: const Icon(Icons.bug_report),
                label: const Text('运行诊断'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MorandiGreenTheme.accent,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await WebViewHelperImproved.healthCheck();
                  _showSuccessSnackBar('健康检查: ${result ? "通过" : "失败"}');
                },
                icon: const Icon(Icons.health_and_safety),
                label: const Text('健康检查'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MorandiGreenTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_debugInfo != null) ...[
            const Text(
              '诊断结果:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(_debugInfo),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _restartWebView() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在重启WebView环境...';
    });

    try {
      await WebViewHelperImproved.restart();

      final isSupported = await WebViewHelperImproved.isWebViewAvailable();

      setState(() {
        _isWebViewSupported = isSupported;
        _isPreInitialized = isSupported;
        _statusMessage = isSupported
            ? '✅ WebView重启成功'
            : '❌ WebView重启后仍不可用';
      });

      _showSuccessSnackBar(isSupported ? 'WebView重启成功' : 'WebView重启失败');
    } catch (e) {
      _showErrorSnackBar('重启WebView失败: $e');
      setState(() {
        _statusMessage = '❌ 重启失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '确定',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildStatusCard() {
    Color cardColor;
    Color textColor;
    IconData icon;

    if (_isInitializing) {
      cardColor = MorandiGreenTheme.primaryLight.withOpacity(0.2);
      textColor = MorandiGreenTheme.primaryDark;
      icon = Icons.hourglass_empty;
    } else if (!_isWebViewSupported) {
      cardColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red[700]!;
      icon = Icons.error;
    } else if (_isLoggedIn && _canFetchItems) {
      cardColor = MorandiGreenTheme.primary.withOpacity(0.2);
      textColor = MorandiGreenTheme.primaryDark;
      icon = Icons.check_circle;
    } else if (_isLoggedIn) {
      cardColor = MorandiGreenTheme.accent.withOpacity(0.2);
      textColor = MorandiGreenTheme.primaryDark;
      icon = Icons.warning;
    } else if (_isPreInitialized) {
      cardColor = MorandiGreenTheme.surface;
      textColor = MorandiGreenTheme.primary;
      icon = Icons.check;
    } else {
      cardColor = Colors.grey.withOpacity(0.1);
      textColor = Colors.grey[700]!;
      icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isLoading || _isInitializing) ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '系统状态',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                    if (_platformInfo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        '运行环境: $_platformInfo',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 9,

                        ),maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          Text(
            '- 📢获取盲盒信息请注意：如果抽的盲盒次数多，在没有出现新的盲盒组前，统计结果可能不全，请点击获取更多',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 12),
          Text(
            '- 📱安卓用户：初次使用获取盲盒会超时。请尝试再次获取盲盒、刷新登录状态、退出重开',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (_statusMessage.isNotEmpty)
            Text(
              _statusMessage,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          // if (_isPreInitialized && !_isInitializing) ...[
          //   const SizedBox(height: 8),
          //   Text(
          //     '✅ WebView已预初始化，登录速度更快',
          //     style: TextStyle(
          //       color: MorandiGreenTheme.primary,
          //       fontSize: 12,
          //       fontWeight: FontWeight.w500,
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    WebViewHelperImproved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MorandiGreenTheme.background,
      appBar: AppBar(
        title: Text('盲盒记录查询工具'),
        elevation: 2,
        backgroundColor: MorandiGreenTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined),
            tooltip: '调试面板',
            onPressed: _toggleDebugPanel,
          ),
          if (Platform.isMacOS && _isWebViewSupported)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重启WebView',
              onPressed: _isLoading ? null : _restartWebView,
            ),
          LoginStatusWidget(
            isLoggedIn: _isLoggedIn,
            onLogout: () async {
              setState(() {
                _statusMessage = '正在退出登录...';
              });

              try {
                // 1. 清除AuthService中的所有数据
                await _authService.logout();
                
                // 2. 清除WebView数据和Cookie
                await _clearWebViewData();
                
                // 3. 重置应用内的所有状态
                setState(() {
                  _isLoggedIn = false;
                  _canFetchItems = false;
                  _hasToken = false;
                  _isGettingToken = false;
                  _allRecords.clear();
                  _mysteryBoxGroups.clear();
                  _currentPage = 0;
                  _statusMessage = '✅ 已退出登录，所有数据已清除';
                });
                
                _showSuccessSnackBar('已退出登录');
                print('登出完成：所有数据已清除，状态已重置');
                
              } catch (e) {
                print('登出过程出现异常: $e');
                // 即使出现异常也要重置状态
                setState(() {
                  _isLoggedIn = false;
                  _canFetchItems = false;
                  _hasToken = false;
                  _isGettingToken = false;
                  _allRecords.clear();
                  _mysteryBoxGroups.clear();
                  _currentPage = 0;
                  _statusMessage = '⚠️ 登出过程出现异常，但已重置本地状态';
                });
                _showErrorSnackBar('登出时出现异常，请重启应用确保完全清除');
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 调试面板
          if (_showDebugPanel)
            SliverToBoxAdapter(child: _buildDebugPanel()),
          
          // 紧凑的操作面板
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态卡片
                      _buildStatusCard(),

                      const SizedBox(height: 12),

                      // 操作按钮
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // 手动检查登录状态按钮
                          ElevatedButton.icon(
                            onPressed: (_isLoading || _isInitializing)
                                ? null
                                : () async {
                                    setState(() {
                                      _statusMessage = '正在检查登录状态...';
                                    });
                                    await _checkLoginStatus();
                                  },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('刷新登录状态'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MorandiGreenTheme.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),

                          ElevatedButton.icon(
                            onPressed: (_isLoggedIn || _isLoading || _isInitializing)
                                ? null
                                : _openLoginPage,
                            icon: Icon(_isLoggedIn ? Icons.check_circle : Icons.login, size: 18),
                            label: Text(_isLoggedIn ? '已登录' : '登录'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoggedIn ? MorandiGreenTheme.primary : MorandiGreenTheme.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),

                          ElevatedButton.icon(
                            onPressed: (!_isLoggedIn || _isLoading || _isInitializing || _hasToken || _isGettingToken)
                                ? null
                                : _extractToken,
                            icon: _isGettingToken
                                ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : Icon(_hasToken ? Icons.check_circle : Icons.card_giftcard, size: 18),
                            label: Text(_hasToken ? '✅已获取Token' : '②获取Token'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasToken ? MorandiGreenTheme.primaryDark : MorandiGreenTheme.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),

                          ElevatedButton.icon(
                            onPressed: (!_hasToken || _isLoading || _isInitializing)
                                ? null
                                : _fetchMysteryBoxRecords,
                            icon: _isLoading && !_isInitializing
                                ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.download, size: 18),
                            label: Text(_currentPage == 0 ? (_hasToken ? '②获取盲盒记录' : '③获取盲盒记录') : '④获取更多记录'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MorandiGreenTheme.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),

                          
                          if (_allRecords.isNotEmpty) ...[
                            ElevatedButton.icon(
                              onPressed: (_isLoading || _isInitializing) ? null : _resetData,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('重置数据'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MorandiGreenTheme.primaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // 数据统计
                      if (_allRecords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MorandiGreenTheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: MorandiGreenTheme.primary, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.analytics, color: MorandiGreenTheme.primary, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '数据统计: ${_allRecords.length} 条记录，${_mysteryBoxGroups.length} 个盲盒组',
                                    style: TextStyle(
                                      color: MorandiGreenTheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 数据展示区域
          _mysteryBoxGroups.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isInitializing
                              ? Icons.hourglass_empty
                              : !_isWebViewSupported
                              ? Icons.error_outline
                              : _isPreInitialized
                              ? Icons.inbox
                              : Icons.pending,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isInitializing
                              ? '正在初始化应用...\n如果加载较慢，可以点击下方按钮跳过'
                              : !_isWebViewSupported
                              ? '当前平台WebView不可用\n无法使用完整功能\n\n${Platform.isMacOS ? '请确保macOS系统版本支持WebView' : '请检查系统WebView组件'}'
                              : _isPreInitialized
                              ? '暂无数据，请按照上方说明操作'
                              : '正在准备WebView环境...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        if (_isInitializing) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _skipInitialization,
                            icon: const Icon(Icons.skip_next, size: 20),
                            label: const Text('跳过初始化'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MorandiGreenTheme.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '跳过后可以直接使用登录功能',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: MysteryBoxGroupWidget(
                          group: _mysteryBoxGroups[index],
                        ),
                      );
                    },
                    childCount: _mysteryBoxGroups.length,
                  ),
                ),
        ],
      ),
    );
  }
}
