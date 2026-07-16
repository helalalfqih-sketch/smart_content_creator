import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlanIndex = 1; // 0 for Monthly, 1 for Yearly (Default)

  @override
  Widget build(BuildContext context) {
    final SubscriptionService service = Get.find<SubscriptionService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 🌌 Galactic Background
            _buildBackground(),
            
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildPremiumHeader(),
                          const SizedBox(height: 30),
                          _buildPlanSelector(),
                          const SizedBox(height: 30),
                          _buildFeaturesList(),
                          const SizedBox(height: 30),
                          _buildYemeniWalletsSection(), // 🇾🇪 New section for local payments
                          const SizedBox(height: 40),
                          _buildActionButton(service),
                          const SizedBox(height: 20),
                          _buildRestoreAndFooter(service),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF000000),
                  Color(0xFF1E1B4B),
                ],
              ),
            ),
          ),
        ),
        // Glow Effect 1
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        // Glow Effect 2
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.1),
                  blurRadius: 150,
                  spreadRadius: 100,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  "دفع آمن",
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balancing
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primary, Colors.amber],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, size: 40, color: Colors.black),
        ),
        const SizedBox(height: 20),
        Text(
          "ارتقِ بمحتواك للقمة",
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "افتح كافة أدوات الذكاء الاصطناعي وصناعة الفيديو",
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelector() {
    return Column(
      children: [
        _buildPlanCard(
          index: 1,
          title: "الباقة السنوية (Elite)",
          price: "4.99\$",
          period: "/شهرياً",
          description: "وفر 50% - تُدفع سنوياً (59.9\$)",
          isPopular: true,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          index: 0,
          title: "الباقة الشهرية (Pro)",
          price: "9.99\$",
          period: "/شهرياً",
          description: "دفع شهري مرن - يمكن الإلغاء دائماً",
          isPopular: false,
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    required String description,
    required bool isPopular,
  }) {
    final bool isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primary.withValues(alpha: 0.1) 
            : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primary.withValues(alpha: 0.5) 
              : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "الأفضل قيمة",
                            style: GoogleFonts.cairo(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: period,
                        style: GoogleFonts.cairo(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      "ذكاء اصطناعي غير محدود للمحتوى",
      "تحويل الصور لفيديوهات بدقة 4K",
      "إزالة خلفية الفيديو بضغطة واحدة",
      "بحث ترندات TikTok و Instagram العميق",
      "إنشاء سيناريوهات فيديو احترافية",
      "بدون علامات مائية أو إعلانات",
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f,
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildYemeniWalletsSection() {
    final wallets = [
      {'name': 'الكريمي', 'id': '1581785', 'icon': Icons.account_balance},
      {'name': 'محفظتك', 'id': '974486', 'icon': Icons.wallet},
      {'name': 'فلوسك', 'id': '798291', 'icon': Icons.payments},
      {'name': 'جوالي', 'id': '829097', 'icon': Icons.phone_android},
      {'name': 'جيب', 'id': '506222', 'icon': Icons.shopping_bag},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_atm, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                "الدفع عبر المحافظ اليمنية (حاسب)",
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...wallets.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(w['icon'] as IconData, size: 18, color: Colors.white54),
                  const SizedBox(width: 10),
                  Text(w['name'] as String, style: GoogleFonts.cairo(color: Colors.white, fontSize: 13)),
                  const Spacer(),
                  Text(w['id'] as String, style: GoogleFonts.roboto(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.white38),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: w['id'] as String));
                      Get.snackbar('تم النسخ', 'تم نسخ رقم ${w['name']}');
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButton(SubscriptionService service) {
    return Obx(() {
      final bool loading = service.isLoading.value;
      
      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [AppTheme.primary, const Color(0xFF10B981)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : () => _handlePayment(service),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: loading 
            ? const SizedBox(
                width: 24, 
                height: 24, 
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : Text(
                _selectedPlanIndex == 1 ? "تفعيل الباقة السنوية" : "تفعيل الباقة الشهرية",
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
        ),
      );
    });
  }

  Future<void> _handlePayment(SubscriptionService service) async {
    // 💡 التحقق من التوافر الإقليمي
    // إذا كان IAP متاحاً نستخدمه، وإذا فشل أو كنا في منطقة يمنية ننتقل للواتساب
    if (service.isAvailable.value && service.products.isNotEmpty) {
      await service.buySubscription();
    } else {
      final plan = _selectedPlanIndex == 1 ? "Elite (Yearly)" : "Pro (Monthly)";
      final url = Uri.parse('https://wa.me/967771370740?text=${Uri.encodeComponent("مرحباً، أود الاشتراك في باقة $plan.\nتم التحويل عبر خدمة حاسب.\nيرجى تفعيل الاشتراك.")}');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        Get.snackbar('خطأ', 'لا يمكن فتح تطبيق WhatsApp');
      }
    }
  }

  Widget _buildRestoreAndFooter(SubscriptionService service) {
    return Column(
      children: [
        TextButton(
          onPressed: () => service.restorePurchases(),
          child: Text(
            "استعادة المشتريات",
            style: GoogleFonts.cairo(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "بالاشتراك، أنت توافق على شروط الخدمة وسياسة الخصوصية. سيتم تجديد الاشتراك تلقائياً ما لم يتم الإلغاء قبل 24 ساعة من نهاية الفترة.",
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white24, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
