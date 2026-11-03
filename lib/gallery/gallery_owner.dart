import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

/// Keep library attachments and the full gallery in the same account namespace.
String currentGalleryOwner() {
  final auth = Get.find<AuthController>();
  if (!auth.isLoggedIn) return 'guest';
  return 'account:${auth.user?['firestore_uid'] ?? auth.user?['id'] ?? auth.userEmail ?? 'guest'}';
}
