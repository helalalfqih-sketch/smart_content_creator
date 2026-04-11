import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'شروط الاستخدام',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('اتفاقية الاستخدام'),
              _buildText(
                'باستخدامك لتطبيق "Smart Content Creator"، فإنك توافق على الالتزام بالشروط والأحكام التالية. يرجى قراءتها بعناية قبل البدء.',
              ),
              const SizedBox(height: 24),
              _buildHeader('1. ملكية المحتوى'),
              _buildBullet(
                  'أنت تمتلك كامل الحقوق للمحتوى الذي يتم إنشاؤه، ولكنك تمنحنا رخصة تقنية لمعالجته وتقديمه لك.'),
              _buildBullet(
                  'يجب عدم استخدام التطبيق لإنشاء محتوى ينتهك حقوق الملكية الفكرية للآخرين.'),
              const SizedBox(height: 24),
              _buildHeader('2. الاستخدام المقبول'),
              _buildBullet(
                  'يُمنع استخدام التطبيق لإنشاء محتوى غير قانوني، مسيء، أو يحرض على الكراهية.'),
              _buildBullet(
                  'نحن نحتفظ بالحق في تعليق حساب أي مستخدم يخالف هذه المعايير.'),
              const SizedBox(height: 24),
              _buildHeader('3. الاشتراكات والمدفوعات'),
              _buildText(
                'بعض الميزات متوفرة فقط لمشتركي "النسخة المدفوعة". يتم تجديد الاشتراكات تلقائياً ما لم يتم إلغاؤها من قبل المستخدم عبر المتجر الرسمي.',
              ),
              const SizedBox(height: 24),
              _buildHeader('4. حدود المسؤولية'),
              _buildText(
                'نحن نسعى لتقديم أفضل جودة باستخدام الذكاء الاصطناعي، لكننا لا نضمن دقة النتائج بنسبة 100% ولا نتحمل مسؤولية أي قرارات تُبنى عليها.',
              ),
              const SizedBox(height: 24),
              _buildHeader('5. التعديلات'),
              _buildText(
                'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. استمرارك في استخدام التطبيق يعني موافقتك على الشروط المحدثة.',
              ),
              const SizedBox(height: 48),
              Center(
                child: Text(
                  'آخر تحديث: 10 فبراير 2026',
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
        color: Colors.black87,
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
