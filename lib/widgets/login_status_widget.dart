import 'package:flutter/material.dart';

// 莫兰迪绿色系主题颜色
class MorandiGreenTheme {
  static const Color primary = Color(0xFF7D9D8E);      // 主绿色
  static const Color primaryLight = Color(0xFF9BB3A8);  // 浅绿色
  static const Color primaryDark = Color(0xFF5F7A6E);   // 深绿色
  static const Color accent = Color(0xFF8FA89C);        // 强调色
  static const Color background = Color(0xFFF2F5F3);    // 背景色
  static const Color surface = Color(0xFFE8EDE9);       // 表面色
  static const Color surfaceVariant = Color(0xFFDDE4DF); // 表面变体色
}

class LoginStatusWidget extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback? onLogout;

  const LoginStatusWidget({
    super.key,
    required this.isLoggedIn,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 登录状态指示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLoggedIn
                  ? MorandiGreenTheme.surface
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLoggedIn ? MorandiGreenTheme.primary : Colors.red,
                width: 1.5,
              ),
              boxShadow: isLoggedIn ? [
                BoxShadow(
                  color: MorandiGreenTheme.primary.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLoggedIn ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: isLoggedIn ? MorandiGreenTheme.primary : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isLoggedIn ? '已登录' : '未登录',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLoggedIn ? MorandiGreenTheme.primaryDark : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 登出按钮
          if (isLoggedIn && onLogout != null) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: MorandiGreenTheme.primaryDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: MorandiGreenTheme.primaryDark.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: '退出登录',
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}