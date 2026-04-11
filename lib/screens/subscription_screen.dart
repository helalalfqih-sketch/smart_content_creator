import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

import '../services/subscription_service.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject Service
    final SubscriptionService subscriptionService =
        Get.find<SubscriptionService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary,
                const Color(0xFF673AB7),
                Colors.black87,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        _buildMainCard(context),
                        const SizedBox(height: 30),
                        _buildSubscriptionButton(context, subscriptionService),
                        const SizedBox(height: 20),
                        _buildRestoreButton(context, subscriptionService),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          Text(
            'عضوية برو ✨',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 60, color: Colors.amber),
                const SizedBox(height: 20),
                Text(
                  'افتح الإمكانات الكاملة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'كن جزءاً من النخبة المبدعة واحصل على:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 30),
                _buildFeatureItem('ذكاء اصطناعي غير محدود بدون قيود يومية.'),
                _buildFeatureItem('تحليل ترند TikTok متقدم بدقة عالية.'),
                _buildFeatureItem('حوّل صورك إلى فيديو بجودة Premium.'),
                _buildFeatureItem('دعم فني سريع وأولوية في معالجة الطلبات.'),
                _buildFeatureItem('بدون إعلانات وميزات حصرية قادمة.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionButton(
      BuildContext context, SubscriptionService service) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 65,
          margin: const EdgeInsets.only(bottom: 12),
          child: Obx(() {
            if (service.isLoading.value) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.amber));
            }

            final product =
                service.products.isNotEmpty ? service.products.first : null;
            final price = product?.price ?? '9.99\$';

            return ElevatedButton(
              onPressed: () {
                service.buySubscription();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 5,
              ),
              child: Text(
                'اشترك الآن بـ $price شهرياً',
                style: GoogleFonts.cairo(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ),
        Text(
          'يمكنك الإلغاء في أي وقت من إعدادات المتجر',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildRestoreButton(
      BuildContext context, SubscriptionService service) {
    return TextButton(
      onPressed: () {
        service.restorePurchases();
      },
      child: Text(
        'استعادة المشتريات السابقة',
        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
