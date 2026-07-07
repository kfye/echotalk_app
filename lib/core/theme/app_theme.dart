import 'package:flutter/material.dart';

/// EchoTalk 设计系统 —— 鼠尾草治愈绿
///
/// 把设计规范(配色 / 字体 / 间距 / 圆角 / 组件)固化成 Dart。
/// 界面里一律引用这里的常量，不要再散写魔法数字或色值，
/// 改一处即可全局生效。
///
/// 字体说明：
///   本文件用 fontFamily='Lexend' + 中文 fallback。两种装字体方式二选一：
///   1) 用 google_fonts 包（最省事，无需手动放字体文件）：
///        在 pubspec.yaml 加 google_fonts，然后把 AppTypography 里的
///        TextStyle 换成 GoogleFonts.lexend(textStyle: ...) 即可。
///   2) 本地字体：把 Lexend 字体文件放进 assets，在 pubspec.yaml 的
///        fonts: 段声明 family: Lexend。中文由系统字体(苹方/思源)兜底。

// ============================================================
// 颜色
// ============================================================
class AppColors {
  AppColors._();

  // —— 品牌 / 主色 ——
  static const Color primary = Color(0xFF6B9080); // 主色·品牌
  static const Color primaryDeep = Color(0xFF4A6B5D); // 深色·CTA / 强调
  static const Color primaryTint = Color(0xFFDCE9E1); // 浅绿·卡片底 / 进度底

  // —— 背景与表面 ——
  static const Color background = Color(0xFFF6F4EF); // 燕麦·页面底
  static const Color surface = Color(0xFFFFFFFF); // 白·卡片
  static const Color border = Color(0xFFE8E6E0); // 细边框

  // —— 文字 ——
  static const Color textPrimary = Color(0xFF2F3E36); // 墨绿·正文
  static const Color textSecondary = Color(0xFF8A938D); // 次要文字
  static const Color textMuted = Color(0xFFB0B7B2); // 弱化 / 注释

  // —— 功能色（治愈系：提示用暖色而非刺眼红，降低挫败感）——
  static const Color success = Color(0xFF6B9080); // 成功·沿用主色系
  static const Color warning = Color(0xFFE0A96D); // 暖琥珀·“再试一次”
  static const Color danger = Color(0xFFD98C7A); // 柔和红·仅用于真正的错误

  // —— 深色模式 ——
  static const Color darkBackground = Color(0xFF1A211D);
  static const Color darkSurface = Color(0xFF232B27);
  static const Color darkBorder = Color(0xFF39423C);
  static const Color darkPrimary = Color(0xFF7FA894); // 深色下略提亮
  static const Color darkPrimaryTint = Color(0xFF2E3B34);
  static const Color darkTextPrimary = Color(0xFFE8EAE6);
  static const Color darkTextSecondary = Color(0xFF9AA39D);
}

// ============================================================
// 间距 —— 8pt 网格
// ============================================================
class AppSpacing {
  AppSpacing._();

  static const double xs = 4; // 元素内细微间隔
  static const double sm = 8; // 相关元素之间
  static const double md = 12; // 紧凑内边距
  static const double lg = 16; // 卡片内边距
  static const double xl = 24; // 屏幕左右边距 / 卡片间
  static const double xxl = 32; // 区块之间
  static const double xxxl = 48; // 大分区

  // 常用的屏幕边距（治愈系留白偏宽）
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: xl, vertical: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
}

// ============================================================
// 圆角
// ============================================================
class AppRadius {
  AppRadius._();

  static const double sm = 8; // 标签 / 输入框
  static const double md = 12; // 卡片
  static const double lg = 16; // 大卡片
  static const double xl = 24; // 底部弹窗
  static const double full = 999; // 胶囊按钮 / 圆形

  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius largeCard = BorderRadius.circular(lg);
  static final BorderRadius sheet = BorderRadius.circular(xl);
  static final BorderRadius pill = BorderRadius.circular(full);
}

// ============================================================
// 字体
// ============================================================
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Lexend';
  // 中文与音标 fallback：苹方(iOS) / 思源(Android) / Noto 覆盖 IPA 符号
  static const List<String> fallback = <String>[
    'PingFang SC',
    'Noto Sans SC',
    'Noto Sans',
  ];

  static const TextStyle wordDisplay = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textMuted,
  );

  /// 音标专用：主色显示，和正文区分。若 IPA 符号显示异常，
  /// 把 fontFamily 换成 'Noto Sans' 或引入 'Charis SIL'。
  static const TextStyle phonetic = TextStyle(
    fontFamily: 'Noto Sans',
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
  );
}

// ============================================================
// 主题组装
// ============================================================
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryDeep,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.background,
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: Color(0xFF10160F),
      secondary: AppColors.darkPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.danger,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
  }

  /// 浅色 / 深色共用的基础配置
  static ThemeData _base(ColorScheme scheme) {
    final bool isLight = scheme.brightness == Brightness.light;
    final Color onSurface = scheme.onSurface;
    final Color borderColor =
        isLight ? AppColors.border : AppColors.darkBorder;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,

      // 文字层级映射到 Material TextTheme
      textTheme: TextTheme(
        displaySmall: AppTypography.wordDisplay.copyWith(color: onSurface),
        titleLarge: AppTypography.h1.copyWith(color: onSurface),
        titleMedium: AppTypography.h2.copyWith(color: onSurface),
        bodyLarge: AppTypography.body.copyWith(color: onSurface),
        bodyMedium: AppTypography.bodySecondary,
        bodySmall: AppTypography.caption,
      ),

      // 主按钮：全圆角胶囊 + 主色，无重阴影
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const StadiumBorder(),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // 次按钮：描边胶囊
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: const StadiumBorder(),
        ),
      ),

      // 文字按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),

      // 卡片：圆角 + 细边，治愈系不靠阴影分层
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: borderColor, width: 0.5),
        ),
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.background : AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      // 标签 / Chip
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? AppColors.primaryTint
            : AppColors.darkPrimaryTint,
        labelStyle: AppTypography.caption.copyWith(
          color: isLight ? AppColors.primaryDeep : AppColors.darkPrimary,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),

      // 进度条
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor:
            isLight ? AppColors.primaryTint : AppColors.darkPrimaryTint,
      ),

      // 底部导航
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor:
            isLight ? AppColors.primaryTint : AppColors.darkPrimaryTint,
        elevation: 0,
      ),

      dividerTheme: DividerThemeData(color: borderColor, thickness: 0.5),
    );
  }
}