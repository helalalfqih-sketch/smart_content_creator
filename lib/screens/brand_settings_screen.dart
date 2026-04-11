import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/brand_identity_model.dart';
import '../services/firestore_user_service.dart';
import '../controllers/auth_controller.dart';
import '../core/widgets/glass_container.dart';

class BrandSettingsController extends GetxController {
  final FirestoreUserService _firestoreService = Get.find<FirestoreUserService>();
  final AuthController _authController = Get.find<AuthController>();

  final Rx<BrandIdentity?> brandIdentity = Rx<BrandIdentity?>(null);
  final RxBool isLoading = false.obs;
  final Rx<File?> selectedLogo = Rx<File?>(null);

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController tiktokController = TextEditingController();
  final TextEditingController industryController = TextEditingController(); // 🆕 Industry/Business Type

  @override
  void onInit() {
    super.onInit();
    _loadBrandIdentity();
  }

  Future<void> _loadBrandIdentity() async {
    final uid = _authController.firebaseUid;
    if (uid == null) return;

    isLoading.value = true;
    try {
      final brand = await _firestoreService.getBrandIdentity(uid);
      if (brand != null) {
        brandIdentity.value = brand;
        nameController.text = brand.storeName ?? '';
        phoneController.text = brand.phone ?? '';
        websiteController.text = brand.website ?? '';
        instagramController.text = brand.instagram ?? '';
        tiktokController.text = brand.tiktok ?? '';
        industryController.text = brand.industry ?? '';
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickLogo() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedLogo.value = File(image.path);
    }
  }

  Future<void> saveSettings() async {
    final uid = _authController.firebaseUid;
    if (uid == null) return;

    isLoading.value = true;
    try {
      // ⚠️ Note: In a real app, you would upload the logo to Firebase Storage first.
      // For now, we'll store the local path or skip logo update if not uploaded.
      // If we had a storage service, we'd use it here.
      
      final updatedBrand = BrandIdentity(
        storeName: nameController.text,
        phone: phoneController.text,
        website: websiteController.text,
        instagram: instagramController.text,
        tiktok: tiktokController.text,
        industry: industryController.text,
        logoUrl: selectedLogo.value?.path ?? brandIdentity.value?.logoUrl, // Fallback to existing
        updatedAt: DateTime.now(),
      );

      await _firestoreService.saveBrandIdentity(uid: uid, brand: updatedBrand);
      brandIdentity.value = updatedBrand;
      
      Get.snackbar("بنجاح", "تم حفظ إعدادات البراند بنجاح ✅",
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("خطأ", "فشل الحفظ: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }
}

class BrandSettingsScreen extends StatelessWidget {
  const BrandSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BrandSettingsController());

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D10),
      appBar: AppBar(
        title: const Text('إعدادات الهوية والبراند 🏷️',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD486)));
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🖼️ اختيار الشعار
              Center(
                child: GestureDetector(
                  onTap: controller.pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 120.r,
                        height: 120.r,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2DD486), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60.r),
                          child: controller.selectedLogo.value != null
                              ? Image.file(controller.selectedLogo.value!, fit: BoxFit.cover)
                              : controller.brandIdentity.value?.logoUrl != null
                                  ? (controller.brandIdentity.value!.logoUrl!.startsWith('http')
                                      ? Image.network(controller.brandIdentity.value!.logoUrl!, fit: BoxFit.cover)
                                      : Image.file(File(controller.brandIdentity.value!.logoUrl!), fit: BoxFit.cover))
                                  : const Icon(Icons.store_rounded, size: 50, color: Colors.white24),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2DD486),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'شعار المتجر / البراند',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // 📝 الحقول النصية
              _buildSectionTitle('المعلومات الأساسية'),
              _buildTextField(controller.nameController, 'اسم المتجر / البراند', Icons.business),
              _buildTextField(controller.industryController, 'نوع النشاط (مثلاً: إلكترونيات، أزياء)', Icons.category_rounded),
              _buildTextField(controller.phoneController, 'رقم الواتساب / التواصل', Icons.phone_android),
              _buildTextField(controller.websiteController, 'الموقع الإلكتروني', Icons.language),
              
              const SizedBox(height: 24),
              _buildSectionTitle('حسابات التواصل'),
              _buildTextField(controller.instagramController, 'يوزر انستقرام (@username)', Icons.camera_alt_outlined),
              _buildTextField(controller.tiktokController, 'يوزر تيك توك (@username)', Icons.music_note),

              const SizedBox(height: 40),

              // 💾 زر الحفظ
              ElevatedButton(
                onPressed: controller.saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD486),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 10,
                  shadowColor: const Color(0xFF2DD486).withValues(alpha: 0.3),
                ),
                child: const Text('حفظ الهوية 🚀',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF2DD486), fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        borderRadius: 16.r,
        opacity: 0.05,
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: Colors.white54),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16.r),
          ),
        ),
      ),
    );
  }
}
