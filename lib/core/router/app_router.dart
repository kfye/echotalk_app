import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/content/presentation/video_play_page.dart';
import '../../features/shell/presentation/main_shell_page.dart';
import '../../features/words/presentation/word_practice_page.dart';
import 'routes.dart';

/// 应用路由。redirect 依据 [AuthState] 做守卫；auth 状态变化经 ValueNotifier
/// 触发 go_router 重新评估 redirect。
final routerProvider = Provider<GoRouter>((ref) {
  // 把 auth 状态变化桥接成 Listenable，驱动 go_router 刷新。
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      switch (auth) {
        case AuthUnknown():
          // 判定中：只允许停在 splash。
          return loc == AppRoutes.splash ? null : AppRoutes.splash;
        case AuthUnauthenticated():
          final atAuthPage =
              loc == AppRoutes.login || loc == AppRoutes.register;
          return atAuthPage ? null : AppRoutes.login;
        case AuthAuthenticated():
          final atEntry = loc == AppRoutes.splash ||
              loc == AppRoutes.login ||
              loc == AppRoutes.register;
          return atEntry ? AppRoutes.home : null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainShellPage(),
      ),
      GoRoute(
        path: '${AppRoutes.video}/:id',
        builder: (context, state) => VideoPlayPage(
          videoId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.wordPractice,
        builder: (context, state) => const WordPracticePage(),
      ),
    ],
  );
});
