import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/home_page.dart';
import '../../content/presentation/content_list_page.dart';

/// 主壳：底部导航（首页/学习/对话/文件/我的）+ IndexedStack。
/// 内测仅「首页」(跟读内容) 与「我的」(个人中心/登出) 可用，其余占位。
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  static const _pages = <Widget>[
    ContentListPage(),
    _ComingSoon('学习'),
    _ComingSoon('对话'),
    _ComingSoon('文件'),
    HomePage(),
  ];

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页'),
    (icon: Icons.article_outlined, activeIcon: Icons.article, label: '学习'),
    (
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: '对话'
    ),
    (icon: Icons.folder_outlined, activeIcon: Icons.folder, label: '文件'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(child: _barItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem(int i) {
    final sel = _index == i;
    final color = sel ? AppColors.primaryDeep : AppColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sel ? _items[i].activeIcon : _items[i].icon,
            size: 25,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            _items[i].label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              fontSize: 12,
              height: 1.0,
              color: color,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('敬请期待', style: AppTypography.bodySecondary),
      ),
    );
  }
}
