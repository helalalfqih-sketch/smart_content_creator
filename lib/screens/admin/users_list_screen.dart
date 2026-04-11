import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/snackbar_utils.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AuthController _auth = Get.find<AuthController>();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _auth.fetchAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _handleDelete(int userId) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف المستخدم'),
        content: const Text(
            'هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              final success = await _auth.removeUser(userId);
              if (success) {
                SnackBarUtils.showSmartSnackBar(
                    title: 'نجاح',
                    message: 'تم حذف المستخدم بنجاح',
                    isError: false);
                _loadUsers();
              } else {
                SnackBarUtils.showSmartSnackBar(
                    title: 'خطأ',
                    message: 'فشل في حذف المستخدم',
                    isError: true);
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handlePromote(int userId, String currentRole) {
    if (currentRole == 'admin') {
      SnackBarUtils.showSmartSnackBar(
          title: 'تنبيه', message: 'المستخدم أدمن بالفعل', isError: false);
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('ترقية المستخدم'),
        content:
            const Text('هل أنت متأكد من منح صلاحيات الأدمن لهذا المستخدم؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              final success = await _auth.promoteToAdmin(userId);
              if (success) {
                SnackBarUtils.showSmartSnackBar(
                    title: 'نجاح',
                    message: 'تمت ترقية المستخدم إلى أدمن',
                    isError: false);
                _loadUsers();
              } else {
                SnackBarUtils.showSmartSnackBar(
                    title: 'خطأ',
                    message: 'فشل في ترقية المستخدم',
                    isError: true);
              }
            },
            child: const Text('ترقية'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('إدارة المستخدمين 👥',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _users.isEmpty
                ? const Center(
                    child: Text('لا يوجد مستخدمين مسجلين',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isMe = user['id'] == _auth.user?['id'];
                      return Card(
                        color: Colors.grey.shade900,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: user['role'] == 'admin'
                                ? Colors.orange
                                : Colors.blue,
                            backgroundImage: (user['photo_url'] != null &&
                                    user['photo_url'].toString().isNotEmpty)
                                ? NetworkImage(user['photo_url'].toString())
                                : null,
                            child: (user['photo_url'] == null ||
                                    user['photo_url'].toString().isEmpty)
                                ? Icon(
                                    user['role'] == 'admin'
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          title: Text(
                            (user['username']?.toString() ?? '').isNotEmpty
                                ? user['username'].toString()
                                : user['email'].toString().split('@')[0],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${user['email']}\nالصلاحية: ${user['role']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          isThreeLine: true,
                          trailing: isMe
                              ? const Chip(
                                  label: Text('أنت',
                                      style: TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.teal)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (user['role'] != 'admin')
                                      IconButton(
                                        icon: const Icon(Icons.upgrade,
                                            color: Colors.blue),
                                        onPressed: () => _handlePromote(
                                            user['id'], user['role']),
                                        tooltip: 'ترقية لأدمن',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _handleDelete(user['id']),
                                      tooltip: 'حذف المستخدم',
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
