import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart'; // لحفظ الصور في المعرض
import '../services/ai_image_generation_service.dart';
import '../services/product_photography_service.dart';
import '../models/product_photo_models.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../services/product_memory_service.dart';
import '../controllers/auth_controller.dart';
import '../core/widgets/glass_container.dart';

// =============================================================================
// 🎮 Controller: منطق التحكم الخاص بهذه الشاشة
// =============================================================================
class ProductStudioController extends GetxController {
  // الخدمات
  final AiImageGenerationService _aiService =
      Get.find<AiImageGenerationService>();
  final ProductPhotographyService _photographyService =
      Get.put(ProductPhotographyService()); // استخدام خدمة التصوير الاحترافية

  // المتغيرات التفاعلية (State)
  final Rx<File?> selectedImage = Rx<File?>(null);
  final Rx<File?> selectedBox = Rx<File?>(null);
  final Rx<File?> selectedTemplate = Rx<File?>(null);
  final RxBool useBranding = true.obs;
  
  final Rx<File?> generatedImage = Rx<File?>(null);
  final RxBool isLoading = false.obs;
  final RxString statusMessage = "".obs;

  // التحكم في النصوص
  final TextEditingController promptController = TextEditingController();

  // الأنماط الجاهزة (Presets)
  final RxString selectedStyle = "Professional".obs;
  final List<Map<String, String>> styles = [
    {
      'name': 'Professional',
      'label': '🎯 إعلان احترافي',
      'image': 'assets/images/styles/WhatsApp Image 2026-03-28 at 9.14.03 PM.jpeg',
      'prompt': 'Cinematic advertisement, professional product layout, sharp details, commercial lighting, high contrast'
    },
    {
      'name': 'Cinematic',
      'label': '🎬 سينمائي',
      'image': 'assets/images/styles/cinematic.png',
      'prompt': 'Cinematic lighting, professional studio, 8k, highly detailed'
    },
    {
      'name': 'Luxury',
      'label': '💎 فاخر',
      'image': 'assets/images/styles/luxury.png',
      'prompt':
          'Luxury marble table, bokeh background, golden hour lighting, premium feel'
    },
    {
      'name': 'Nature',
      'label': '🌿 طبيعي',
      'image': 'assets/images/styles/nature.png',
      'prompt':
          'On a wooden table in a forest, sunlight filtering through leaves, natural vibes'
    },
    {
      'name': 'Neon',
      'label': '🟣 نيون',
      'image': 'assets/images/styles/neon.png',
      'prompt':
          'Cyberpunk city background, neon blue and pink lights, futuristic reflection'
    },
    {
      'name': 'Minimal',
      'label': '⚪ بسيط',
      'image': 'assets/images/styles/minimal.png',
      'prompt':
          'Clean white background, soft shadows, minimalist product photography'
    },
    {
      'name': 'Kitchen',
      'label': '🍳 مطبخ',
      'image': 'assets/images/styles/kitchen.png',
      'prompt':
          'Modern kitchen counter, blurred background ingredients, bright lighting'
    },
  ];

  @override
  void onInit() {
    super.onInit();
    // 📥 استقبال الصورة من الشات (إذا وجدت)
    if (Get.arguments != null) {
      if (Get.arguments is File) {
        selectedImage.value = Get.arguments as File;
      } else if (Get.arguments is String) {
        selectedImage.value = File(Get.arguments);
      }
    }
  }

  /// 📸 اختيار صورة من المعرض (المنتج)
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage.value = File(image.path);
      generatedImage.value = null; // تصفير النتيجة السابقة
    }
  }

  /// 📦 اختيار صورة الصندوق (Packaging)
  Future<void> pickBoxImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedBox.value = File(image.path);
    }
  }

  /// 🖼️ اختيار قالب يدوي (Custom Template)
  Future<void> pickTemplateImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedTemplate.value = File(image.path);
    }
  }

  /// 🎨 تنفيذ عملية التوليد
  Future<void> generateBackground() async {
    if (selectedImage.value == null) {
      Get.snackbar("تنبيه", "يرجى اختيار صورة المنتج أولاً",
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (promptController.text.isEmpty && selectedStyle.value.isEmpty) {
      Get.snackbar("تنبيه", "يرجى كتابة وصف للخلفية أو اختيار نمط",
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    isLoading.value = true;
    generatedImage.value = null;
    statusMessage.value = "جاري تحسين الوصف وتحليل المشهد... ✨";
    
    ProductPhotoResult? photoResult; // المتغير الذي سيحمل النتيجة للذاكرة

    try {
      // 1. تجهيز البرومبت النهائي
      String stylePrompt = styles
              .firstWhere((s) => s['name'] == selectedStyle.value)['prompt'] ??
          "";
      String finalPrompt = "${promptController.text}. $stylePrompt";

      // 2. التحقق من نمط الإعلان الاحترافي
      if (selectedStyle.value == "Professional" || selectedBox.value != null || selectedTemplate.value != null) {
        // 🛡️ التحقق من مفاتيح API الضرورية
        final settings = Get.find<SettingsController>();
        final hasStability = settings.getApiKey(ProviderType.stability).isNotEmpty;
        final hasRemoveBg = settings.getApiKey(ProviderType.removebg).isNotEmpty;

        if (!hasStability) {
          Get.snackbar("تنبيه", "يرجى إضافة مفتاح Stability AI في الإعدادات لتوليد الإعلانات",
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange.withValues(alpha: 0.1));
          isLoading.value = false;
          return;
        }

        if (!hasRemoveBg) {
          Get.snackbar("ملاحظة", "سيتم التوليد بدون تفريغ الخلفية لعدم وجود مفتاح Remove.bg. النتائج قد تكون أقل دقة.",
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.blue.withValues(alpha: 0.1));
        }

        statusMessage.value = "جاري تحضير ودمج الصور... 🖌️";
        final result = await _photographyService.generateBrandedMarketingAd(
          productImage: selectedImage.value!,
          boxImage: selectedBox.value,
          templateImage: selectedTemplate.value,
          useBranding: useBranding.value,
          customPrompt: finalPrompt,
        );

        photoResult = result; // حفظ النتيجة للذاكرة

        if (result.success && result.generatedImage != null) {
          generatedImage.value = result.generatedImage;
          statusMessage.value = "تم بنجاح! 🎉";
        } else {
           Get.snackbar("خطأ", result.error ?? "فشل في توليد الإعلان",
              backgroundColor: Colors.red, colorText: Colors.white);
           statusMessage.value = "حدث خطأ ❌";
        }
      } else {
        // 3. استدعاء الدالة الأصلية في الحالات العادية
        statusMessage.value = "جاري التوليد الاحترافي... 🎨";

        final result = await _aiService.generateProfessionalProductPhoto(
          originalImageFile: selectedImage.value!,
          prompt: finalPrompt,
        );

        // تحويل ImageGenerationResult لـ ProductPhotoResult للذاكرة
        photoResult = ProductPhotoResult.successResult(
          image: result.file ?? selectedImage.value!,
          prompt: ScenePrompt(
            id: 'direct_gen',
            titleAr: selectedStyle.value,
            titleEn: selectedStyle.value,
            descriptionAr: '',
            promptEn: finalPrompt,
            style: ProductPhotoStyle.cinematic,
          ),
        );

        if (result.success && result.localPath != null) {
          generatedImage.value = File(result.localPath!);
          statusMessage.value = "تم بنجاح! 🎉";
        } else {
          Get.snackbar("خطأ", result.error ?? "فشل في التوليد",
              backgroundColor: Colors.red, colorText: Colors.white);
          statusMessage.value = "حدث خطأ ❌";
        }
      }

      // 🧠 تحديث ذاكرة المنتج (Context Awareness)
      if (generatedImage.value != null) {
        try {
          final memoryService = Get.find<ProductMemoryService>();
          final authController = Get.find<AuthController>();
          final analysis = photoResult.analysis;

          await memoryService.saveProductMemory(
            userId: authController.firebaseUid ?? 'guest',
            productName: analysis?.productType ?? promptController.text,
            productNameEn: analysis?.productType ?? '',
            brandName: analysis?.rawData['brand'] ?? analysis?.rawData['brand_name'] ?? 'N/A',
            category: analysis?.rawData['category'] ?? 'General',
            imagePath: generatedImage.value!.path,
            searchQuery: promptController.text,
          );
        } catch (e) {
          debugPrint("⚠️ Failed to update product memory: $e");
        }
      }
    } catch (e) {
      Get.snackbar("خطأ غير متوقع", e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
      statusMessage.value = "حدث خطأ ❌";
    } finally {
      isLoading.value = false;
    }
  }

  /// 💾 حفظ الصورة
  Future<void> saveImage() async {
    if (generatedImage.value == null) return;
    try {
      await Gal.putImage(generatedImage.value!.path);
      Get.snackbar("تم الحفظ", "تم حفظ الصورة في المعرض ✅",
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("خطأ", "فشل الحفظ: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// 🔗 مشاركة الصورة
  Future<void> shareImage() async {
    if (generatedImage.value == null) return;
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(generatedImage.value!.path)],
        text: 'تم التصميم بواسطة صانع المحتوى الذكي 🎨');
  }
}

// =============================================================================
// 📱 Screen: واجهة المستخدم
// =============================================================================
class ProductPhotographyScreen extends StatelessWidget {
  const ProductPhotographyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // حقن الكونترولر
    final controller = Get.put(ProductStudioController());
    final bool isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    return Stack(
      children: [
        // 🌌 Galactic Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF000000),
                Color(0xFF0F0F1A),
                Color(0xFF1A1A2E),
              ],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              "استوديو المنتجات AI 🎨",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Colors.purpleAccent, Colors.blueAccent],
                  ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── الجانب الأيسر: المعاينة ───
                Expanded(
                  flex: 3,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(32.r),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 600.w),
                        child: _buildImagePreview(controller),
                      ),
                    ),
                  ),
                ),

                // ─── فاصل رفيع ───
                Container(width: 1, color: Colors.white12),

                // ─── الجانب الأيمن: أدوات التحكم ───
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.r),
                    child: _buildControlPanel(controller),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildControlPanel(controller, includePreview: true),
            ),
        ),
      ],
    );
  }

  // دمج أدوات التحكم في ودجت واحد لسهولة التبديل
  Widget _buildControlPanel(ProductStudioController controller,
      {bool includePreview = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includePreview) ...[
          _buildImagePreview(controller),
          const SizedBox(height: 24),
        ],

        // 2️⃣ إدخال الوصف (Prompt)
        Text(
          "أين تريد وضع منتجك؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20.r,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: controller.promptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "مثال: على طاولة خشبية في حديقة مشمسة...",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16.r),
              prefixIcon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 🆕 إعدادات الهوية والبراند
        Obx(() => Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Icon(Icons.verified_user_rounded, color: Colors.orange, size: 20.sp),
                   SizedBox(width: 8.w),
                   Text("دمج معلومات الهوية والشعار", style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ],
              ),
              Switch(
                value: controller.useBranding.value,
                onChanged: (v) => controller.useBranding.value = v,
                activeThumbColor: Colors.orange,
                activeTrackColor: Colors.orange.withValues(alpha: 0.3),
              ),
            ],
          ),
        )),

        const SizedBox(height: 24),

        // 🆕 اختيار القالب أو الصندوق
        Text(
          "الإضافات والتدعيم",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMiniUploadCard(
              title: "صورة الصندوق",
              icon: Icons.inventory_2_rounded,
              image: controller.selectedBox,
              onTap: controller.pickBoxImage,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniUploadCard(
              title: "قالب يدوي",
              icon: Icons.dashboard_customize_rounded,
              image: controller.selectedTemplate,
              onTap: controller.pickTemplateImage,
            )),
          ],
        ),

        const SizedBox(height: 24),

        // 3️⃣ اختيار النمط (Styles)
        Text(
          "اختر النمط (Style)",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            scrollDirection: Axis.horizontal,
            itemCount: controller.styles.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final style = controller.styles[index];
              return Obx(() {
                final isSelected =
                    controller.selectedStyle.value == style['name'];
                return GestureDetector(
                  onTap: () => controller.selectedStyle.value = style['name']!,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: isSelected ? Colors.purpleAccent : Colors.white10,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.purpleAccent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            style['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.white10,
                              child: const Icon(Icons.image, color: Colors.white24),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Text(
                              style['label']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              });
            },
          ),
        ),

        const SizedBox(height: 32),

        // 4️⃣ زر التوليد
        Obx(() => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: -5,
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : controller.generateBackground,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r)),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return null; // Handle via decoration
                  }),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.purpleAccent, Colors.blueAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    alignment: Alignment.center,
                    child: controller.isLoading.value
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 24.r,
                                  height: 24.r,
                                  child: const CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3)),
                              const SizedBox(width: 12),
                              Text(controller.statusMessage.value,
                                  style: TextStyle(
                                      fontSize: 16.sp, color: Colors.white)),
                            ],
                          )
                        : Text(
                            "توليد السحر الفني ✨",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),
              ),
            )),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImagePreview(ProductStudioController controller) {
    return Obx(() {
      final hasOriginal = controller.selectedImage.value != null;
      final hasGenerated = controller.generatedImage.value != null;

      return GlassContainer(
        height: 380.h,
        borderRadius: 30.r,
        opacity: 0.05,
        border: Border.all(color: Colors.white12),
        child: !hasOriginal
            ? InkWell(
                onTap: controller.pickImage,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_a_photo_rounded,
                          size: 50.r, color: Colors.purpleAccent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "اضغط لاختيار صورة المنتج",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // الصورة المعروضة
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30.r),
                    child: Image.file(
                      hasGenerated
                          ? controller.generatedImage.value!
                          : controller.selectedImage.value!,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Overlay Gradient
                  if (!controller.isLoading.value)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // أزرار التحكم العلوية
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Row(
                      children: [
                        if (hasGenerated)
                          _glassIconButton(
                            Icons.undo,
                            () => controller.generatedImage.value = null,
                            tooltip: "العودة للأصلية",
                          ),
                        const SizedBox(width: 10),
                        _glassIconButton(
                          Icons.camera_alt_outlined,
                          controller.pickImage,
                          tooltip: "تغيير الصورة",
                        ),
                      ],
                    ),
                  ),

                  // أزرار الحفظ والمشاركة
                  if (hasGenerated && !controller.isLoading.value)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _actionBtn(Icons.save_alt_rounded, "حفظ",
                              Colors.green.withValues(alpha: 0.8), controller.saveImage),
                          _actionBtn(Icons.share_rounded, "مشاركة",
                              Colors.blue.withValues(alpha: 0.8), controller.shareImage),
                        ],
                      ),
                    ),

                  // مؤشر التحميل (Glassy Overlay)
                  if (controller.isLoading.value)
                    GlassContainer(
                      blur: 10,
                      opacity: 0.6,
                      color: Colors.black,
                      borderRadius: 30.r,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.purpleAccent),
                            const SizedBox(height: 20),
                            Text(
                              "جاري إبراز الجمال...",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                ],
              ),
      );
    });
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return GlassContainer(
      width: 45.r,
      height: 45.r,
      borderRadius: 15.r,
      opacity: 0.2,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22.sp),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildMiniUploadCard({
    required String title,
    required IconData icon,
    required Rx<File?> image,
    required VoidCallback onTap,
  }) {
    return Obx(() => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: image.value != null ? Colors.purpleAccent : Colors.white12,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: image.value != null
              ? Image.file(image.value!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white24, size: 24.sp),
                    const SizedBox(height: 8),
                    Text(title, style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                  ],
                ),
        ),
      ),
    ));
  }
}
