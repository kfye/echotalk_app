/// 路由路径常量。集中管理，避免各处硬编码字符串。
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const profile = '/profile';

  /// 播放页基址，实际路由为 `/video/:id`。
  static const video = '/video';

  /// 高频3000单词·口语速练页。
  static const wordPractice = '/words/practice';
}
