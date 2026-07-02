/// 表单校验器。登录/注册共用，规则对齐后端约束（如密码 minLength 6）。
class Validators {
  Validators._();

  /// 中国大陆手机号（注册/登录 identifier）。
  static String? phone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(s)) return '手机号格式不正确';
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '请输入邮箱';
    if (!s.contains('@') || !s.contains('.')) return '邮箱格式不正确';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return '请输入密码';
    if (s.length < 6) return '密码至少 6 位';
    return null;
  }

  static String? notEmpty(String? v, String label) {
    if ((v?.trim() ?? '').isEmpty) return '请输入$label';
    return null;
  }
}
