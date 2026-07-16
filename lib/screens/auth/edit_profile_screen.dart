import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/profile_sync_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 🎨 شاشة تعديل الملف الشخصي الاحترافية - إصدار "Cyber Blue"
/// تصميم مستوحى من شعار التطبيق مع زجاج شفاف (Glassmorphism) ولمسات زرقاء وبنفسجية نيون.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthController _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _bgAnimation;

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  File? _profileImage;
  File? _coverImage;

  // 🔵 الألوان الخاصة بالنمط التقني الموحد (مستوحى من الشعار)
  static const Color cyberBlue = Color(0xFF3B59FF);
  static const Color cyberCyan = Color(0xFF00D2FF);
  static const Color cyberPurple = Color(0xFF8A2BE2);

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _nameController = TextEditingController(
      text: (_auth.user?['name'] ?? _auth.user?['username'] ?? '').toString(),
    );
    _bioController =
        TextEditingController(text: _auth.user?['bio']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else {
            _coverImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    _auth.clearError();

    try {
      final bool success = await _auth.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: _profileImage?.path,
        coverUrl: _coverImage?.path,
      );

      if (success) {
        Get.find<ProfileSyncService>().syncProfile();
        SnackBarUtils.showSuccess(
            'تم الحفظ', 'تم تحديث بياناتك بنجاح وجاري المزامنة...');
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Get.back();
        });
      } else {
        SnackBarUtils.showError(
            'خطأ', _auth.currentError.value ?? 'فشل التحديث');
      }
    } catch (e) {
      SnackBarUtils.showError('خطأ تقني', 'حدث خطأ غير متوقع');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1️⃣ الخلفية التقنية (الدوائر المتكاملة)
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: Image.asset(
                  'assets/images/styles/WhatsApp Image 2026-03-28 at 9.14.03 PM.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // 2️⃣ تأثير المجرة المتحرك (اختياري للجمالية)
            GalacticBackgroundUnified(
                animation: _bgAnimation, starOpacity: 0.15),

            // 3️⃣ المحتوى الرئيسي
            Positioned.fill(
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 100), // مسافة للصورة المتداخلة
                            _buildGlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle("المعلومات الأساسية"),
                                  const SizedBox(height: 20),
                                  _buildCyberTextField(
                                    label: "الاسم المستعار",
                                    controller: _nameController,
                                    icon: Icons.person_rounded,
                                    hint: "مثلاً: صانع المحتوى الذكي",
                                  ),
                                  const SizedBox(height: 25),
                                  _buildCyberTextField(
                                    label: "نبذة عنك",
                                    controller: _bioController,
                                    icon: Icons.auto_awesome_rounded,
                                    hint: "أخبر المتابعين بشيء مذهل...",
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildSaveButton(),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4️⃣ قسم الصور المتداخل (Fixed on Scroll with custom logic or simply in Stack)
            _buildOverlappingImages(),
          ],
        ),
      ),
    );
  }

  /// 🔝 شريط التطبيق الشفاف
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.h,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'تعديل الحساب',
        style: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: () => _pickImage(ImageSource.gallery, false),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Image
              if (_coverImage != null)
                Image.file(_coverImage!, fit: BoxFit.cover)
              else if (_auth.user?['cover_url'] != null)
                _buildNetworkImage((_auth.user?['cover_url'] ?? '').toString())
              else
                Container(
                  color: Colors.white10,
                  child: const Icon(Icons.add_photo_alternate_rounded,
                      size: 40, color: Colors.white24),
                ),
              // Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 👤 الصور المتداخلة (Avatar over Cover)
  Widget _buildOverlappingImages() {
    return Positioned(
      top: 130.h,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _pickImage(ImageSource.gallery, true),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: 130.r,
                height: 130.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cyberBlue.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              // Avatar Border
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cyberBlue, cyberPurple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 58.r,
                    backgroundColor: AppTheme.surfaceColor,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_getImageProvider((_auth.user?['photo_url'] ??
                                _auth.user?['profile_url'] ??
                                '')
                            .toString())),
                    child: (_profileImage == null &&
                            (_auth.user?['photo_url'] ??
                                    _auth.user?['profile_url']) ==
                                null)
                        ? const Icon(Icons.camera_alt_rounded,
                            size: 30, color: Colors.white24)
                        : null,
                  ),
                ),
              ),
              // Edit Icon Badge
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: cyberBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧊 بطاقة زجاجية شفافة
  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// ⌨️ حقل إدخال "Cyber"
  Widget _buildCyberTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: cyberCyan,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white30, fontSize: 14.sp),
            prefixIcon: Icon(icon, color: cyberCyan, size: 20),
            filled: true,
            fillColor: Colors.black26,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: cyberBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// 🏷️ عنوان القسم
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: cyberBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 💾 زر الحفظ المتوهج
  Widget _buildSaveButton() {
    return Obx(() => GestureDetector(
          onTap: _auth.isLoading.value ? null : _handleSave,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [cyberBlue, cyberPurple],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: cyberBlue.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: _auth.isLoading.value
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "تأكيد التعديلات",
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ));
  }

  /// 🖼️ مساعد جلب الصور
  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.black),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
            child: CircularProgressIndicator(color: cyberBlue));
      },
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.isEmpty) {
      return const AssetImage('assets/images/styles/logoapp.jpeg');
    }
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return const AssetImage('assets/images/styles/logoapp.jpeg');
  }
}

