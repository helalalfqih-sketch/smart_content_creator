import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'سياسة الخصوصية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('مقدمة'),
              _buildText(
                'نحن في تطبيق "Smart Content Creator" نلتزم بحماية خصوصيتك وبياناتك. توضح هذه السياسة كيفية جمع واستخدام وحماية معلوماتك عند استخدام تطبيقنا.',
              ),
              const SizedBox(height: 24),
              
              _buildHeader('1. البيانات التي نجمعها'),
              _buildBullet('بيانات الحساب: البريد الإلكتروني والاسم عند تسجيل الدخول عبر Google أو البريد.'),
              _buildBullet('المحتوى المرفوع: الصور والفيديوهات التي تختار معالجتها بالذكاء الاصطناعي.'),
              _buildBullet('بيانات الاستخدام: إحصائيات تقنية مجهولة المصدر لتحسين أداء التطبيق.'),
              
              const SizedBox(height: 24),
              _buildHeader('2. كيف نستخدم بياناتك'),
              _buildBullet('توفير خدمات تحرير الفيديو وتوليد المحتوى الذكي.'),
              _buildBullet('مزامنة الإعدادات والتفضيلات عبر أجهزتك المختلفة.'),
              _buildBullet('تحسين خوارزميات الذكاء الاصطناعي وتجربة المستخدم.'),
              
              const SizedBox(height: 24),
              _buildHeader('3. معالجة الذكاء الاصطناعي'),
              _buildText(
                'يتم إرسال الصور والنصوص لخدمات معالجة سحابية (مثل Google Gemini) لتقديم الخدمة المطلوبة. لا نقوم ببيع هذه البيانات لأطراف ثالثة.',
              ),
              
              const SizedBox(height: 24),
              _buildHeader('4. حقوقك وتحكمك'),
              _buildBullet('حق الوصول: يمكنك عرض بياناتك المسجلة في ملفك الشخصي.'),
              _buildBullet('حق الحذف: يمكنك طلب حذف حسابك وبياناتك نهائياً من خلال التطبيق أو التواصل معنا.'),
              
              const SizedBox(height: 24),
              _buildHeader('5. تواصل معنا'),
              _buildText(
                'إذا كان لديك أي استفسار حول سياسة الخصوصية، يمكنك التواصل معنا عبر البريد الإلكتروني: support@smartcc.ai',
              ),
              
              const SizedBox(height: 48),
              Center(
                child: Text(
                  'آخر تحديث: 26 يناير 2026',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 15,
        height: 1.6,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8.0, left: 8.0),
            child: Icon(Icons.circle, size: 6, color: Colors.grey),
          ),
          Expanded(child: _buildText(text)),
        ],
      ),
    );
  }
}
