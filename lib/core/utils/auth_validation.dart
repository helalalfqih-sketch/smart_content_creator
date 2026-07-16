class AuthValidation {
  static String? validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'يرجى إدخال كلمة المرور';
    if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  static String? validateConfirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) return 'يرجى تأكيد كلمة المرور';
    if (password != confirmPassword) return 'كلمة المرور غير متطابقة';
    return null;
  }
}
