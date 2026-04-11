import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/profile_sync_service.dart';

/// 🎨 شاشة تعديل الملف الشخصي الاحترافية
/// تدعم إضافة صورة الغلاف (Cover Photo) والصورة الشخصية وتحديث البيانات الأساسية.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthController _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  File? _profileImage;
  File? _coverImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // جلب البيانات الحالية من الـ Auth Controller
    _nameController = TextEditingController(text: _auth.user?['name']?.toString() ?? '');
    _bioController = TextEditingController(text: _auth.user?['bio']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 📸 دالة اختيار الصورة (شخصية أو غلاف) من المعرض
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

  /// 💾 حفظ التغييرات محلياً أولاً ثم المزامنة في الخلفية
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1️⃣ التحديث المحلي الفوري
      final bool success = await _auth.updateProfile(
        username: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: _profileImage?.path, // حفظ المسار المحلي
        coverUrl: _coverImage?.path, // حفظ المسار المحلي
      );

      if (success) {
        // 2️⃣ بدء المزامنة في الخلفية (بدون انتظار الشاشة لها)
        Get.find<ProfileSyncService>().syncProfile();

        SnackBarUtils.showSuccess(
            'حفظ ناجح', 'تم الحفظ محلياً وجاري المزامنة في الخلفية...');

        // العودة للشاشة السابقة بعد وقت قصير للجمالية
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Get.back();
        });
      } else {
        SnackBarUtils.showError('خطأ', 'فشل التحديث المحلي');
      }
    } catch (e) {
      debugPrint("❌ Save Error: $e");
      SnackBarUtils.showError('خطأ تقني', 'حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعديل الحساب الاحترافي',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (_isLoading)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                  onPressed: _handleSave,
                  icon: const Icon(Icons.check_circle,
                      color: Colors.blue, size: 28))
          ],
        ),
        body: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 🌉 قسم الصور الاحترافي (الغلاف + الشخصية)
                _buildImageSection(),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("الاسم التجاري / الشخصي"),
                      _buildTextField(_nameController, "أدخل اسمك المميز",
                          Icons.person_outline),

                      const SizedBox(height: 24),

                      _buildLabel("نبذة عنك (Bio)"),
                      _buildTextField(
                          _bioController,
                          "أخبر العملاء ماذا تقدم في تطبيقنا...",
                          Icons.edit_note,
                          maxLines: 4),

                      const SizedBox(height: 40),

                      // زر الحفظ الرئيسي بتصميم نيون
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00DCF0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          child: const Text("حفظ التغييرات",
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🏗️ واجهة الصور المتداخلة باستخدام Stack
  Widget _buildImageSection() {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🖼️ الغلاف الخلفي (Cover)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery, false),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  image: _coverImage != null
                      ? DecorationImage(
                          image: FileImage(_coverImage!), fit: BoxFit.cover)
                      : (_auth.user?['cover_url'] != null
                          ? DecorationImage(
                              image: _getImageProvider(
                                  (_auth.user?['cover_url'] ?? '').toString()),
                              fit: BoxFit.cover)
                          : null),
                ),
                child: (_coverImage == null && _auth.user?['cover_url'] == null)
                    ? const Center(
                        child: Icon(Icons.add_photo_alternate_rounded,
                            size: 50, color: Colors.white38))
                    : Container(
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.all(8),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black26,
                          child:
                              Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
              ),
            ),
          ),
          // 👤 الصورة الشخصية (Profile Avatar)
          Positioned(
            bottom: 10,
            child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery, true),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : ((_auth.user?['photo_url'] ??
                                  _auth.user?['profile_url']) !=
                              null
                          ? _getImageProvider((_auth.user?['photo_url'] ??
                                  _auth.user?['profile_url'] ??
                                  '')
                              .toString())
                          : null),
                  child: (_profileImage == null &&
                          (_auth.user?['photo_url'] ??
                                  _auth.user?['profile_url']) ==
                              null)
                      ? const Icon(Icons.camera_alt_rounded,
                          size: 35, color: Colors.grey)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🖼️ محرك جلب الصور (يدعم الروابط والملفات المحلية)
  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http') || path.startsWith('https')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  /// 🏷️ وسم الحقول
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  /// ✍️ حقل الإدخال بتصميم عصري
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00DCF0)),
        filled: true,
        fillColor: const Color.fromARGB(255, 0, 0, 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: const Color.fromARGB(255, 0, 0, 0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF00DCF0), width: 1.5),
        ),
      ),
    );
  }
}
