import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/auth_controller.dart';

class AccountPickerSheet extends StatelessWidget {
  const AccountPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();

    return Obx(() {
      final user = auth.user;
      final String email = user?['email'] ?? 'لم يتم تسجيل الدخول';
      final String name = user?['username'] ?? user?['name'] ?? 'زائر';
      final String photoUrl = user?['photo_url'] ?? '';

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1F22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
                const Spacer(),
                Text(
                  email,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),

          const SizedBox(height: 10),
          _buildMainProfile(name, photoUrl),

          const SizedBox(height: 20),
          _buildManageButton(),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),

          // 🔄 قائمة الحسابات (هنا يمكن إضافة الحسابات المحفوظة محلياً)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // يمكن مستقبلاً جلب قائمة الحسابات من SQLite
                _buildAccountTile(
                  name: 'تبديل الحساب',
                  email: 'تسجيل الدخول بحساب آخر',
                  initial: '+',
                  color: Colors.blueAccent,
                  onTap: () {
                    Get.back();
                    auth.logout(); // الخروج للتبديل
                  },
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1),
          
          _buildActionTile(Icons.person_add_alt_1_outlined, 'إضافة حساب جديد', () {
            Get.back();
            auth.logout();
          }),
          _buildActionTile(Icons.logout_rounded, 'تسجيل الخروج من كافة الحسابات', () {
            Get.back();
            auth.logout();
          }),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  });
}

  Widget _buildMainProfile(String name, String photoUrl) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.red, Colors.yellow, Colors.green],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFF1E1F22), shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white)) : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1F22),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'مرحبًا "$name"',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildManageButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'إدارة حسابك على Google',
        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAccountTile({
    required String name,
    required String email,
    required String initial,
    required Color color,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: hasBorder ? const EdgeInsets.all(2) : null,
        decoration: hasBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              )
            : null,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: color,
          child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
      title: Text(name, style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(email, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(title, style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
