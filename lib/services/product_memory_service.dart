import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/product_memory_model.dart';
import 'db_service.dart';
import 'package:smart_content_creator/controllers/auth_controller.dart'; 

/// 🧠 Product Memory Service
/// خدمة لإدارة ذاكرة المنتجات - حفظ واسترجاع آخر منتج تم تحليله لكل مستخدم
class ProductMemoryService extends GetxService {
  final DBService _dbService = Get.find<DBService>();

  /// 💾 حفظ أو تحديث آخر منتج للمستخدم
  Future<void> saveProductMemory({
    required String userId,
    required String productName,
    String? productNameEn,
    String? brandName,
    String? brandNameEn,
    String? category,
    String? model,
    required String searchQuery,
    String? imagePath,
  }) async {
    try {
      // 🛡️ Identity Sync (v3.1): Robust ID resolution
      final auth = Get.find<AuthController>();
      final resolvedId = userId.isNotEmpty ? userId : auth.firebaseUid;
      if (resolvedId == null) return;

      final now = DateTime.now();
      final productMemory = ProductMemoryModel(
        userId: userId,
        productName: productName,
        productNameEn: productNameEn,
        brandName: brandName,
        brandNameEn: brandNameEn,
        category: category,
        model: model,
        searchQuery: searchQuery,
        imagePath: imagePath,
        createdAt: now,
        updatedAt: now,
      );

      // استخدام Generic CRUD للإضافة أو التحديث
      await _dbService.insertRecord(
        'product_memory',
        productMemory.copyWith(userId: resolvedId).toMap(),
      );

      if (kDebugMode) {
        debugPrint('✅ ProductMemoryService: Saved product memory for user $resolvedId');
        debugPrint('   Product: $productName (${productNameEn ?? "N/A"})');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ ProductMemoryService: Error saving product memory: $e');
        debugPrint(stack.toString());
      }
    }
  }

  /// 📖 استرجاع آخر منتج للمستخدم
  Future<ProductMemoryModel?> getLastProduct(String userId) async {
    try {
      // 🛡️ Identity Sync (v3.1): Robust lookup
      final auth = Get.find<AuthController>();
      final resolvedId = userId.isNotEmpty ? userId : auth.firebaseUid;
      if (resolvedId == null) return null;

      final results = await _dbService.getRecords(
        'product_memory',
        where: 'user_id = ?',
        whereArgs: [resolvedId],
        limit: 1,
      );

      if (results.isEmpty) {
        if (kDebugMode) debugPrint('ℹ️ ProductMemoryService: No product memory found for user $resolvedId');
        return null;
      }

      final product = ProductMemoryModel.fromMap(results.first);
      if (kDebugMode) {
        debugPrint('✅ ProductMemoryService: Retrieved product memory for user $resolvedId');
        debugPrint('   Product: ${product.productName}');
      }
      return product;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ ProductMemoryService: Error retrieving product memory: $e');
        debugPrint(stack.toString());
      }
      return null;
    }
  }

  /// 🗑️ مسح ذاكرة المنتج للمستخدم
  Future<void> clearProductMemory(String userId) async {
    try {
      final auth = Get.find<AuthController>();
      final resolvedId = userId.isNotEmpty ? userId : auth.firebaseUid;
      if (resolvedId == null) return;

      await _dbService.deleteRecord(
        'product_memory',
        where: 'user_id = ?',
        whereArgs: [resolvedId],
      );

      if (kDebugMode) debugPrint('✅ ProductMemoryService: Cleared product memory for user $resolvedId');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProductMemoryService: Error clearing product memory: $e');
      }
    }
  }

  /// ✅ فحص وجود ذاكرة منتج للمستخدم
  Future<bool> hasProductMemory(String userId) async {
    try {
      final auth = Get.find<AuthController>();
      final resolvedId = userId.isNotEmpty ? userId : auth.firebaseUid;
      if (resolvedId == null) return false;

      final results = await _dbService.getRecords(
        'product_memory',
        where: 'user_id = ?',
        whereArgs: [resolvedId],
        limit: 1,
      );

      return results.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ProductMemoryService: Error checking product memory: $e');
      return false;
    }
  }

  /// 🔄 تحديث وقت آخر استخدام للمنتج
  Future<void> updateLastUsed(String userId) async {
    try {
      final auth = Get.find<AuthController>();
      final resolvedId = userId.isNotEmpty ? userId : auth.firebaseUid;
      if (resolvedId == null) return;

      await _dbService.updateRecord(
        'product_memory',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [resolvedId],
      );

      if (kDebugMode) debugPrint('✅ ProductMemoryService: Updated last used timestamp for user $resolvedId');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ProductMemoryService: Error updating last used: $e');
    }
  }
}
