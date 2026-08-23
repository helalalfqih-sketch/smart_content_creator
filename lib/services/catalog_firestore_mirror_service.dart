import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/catalog_product_model.dart';

/// 🪞 CatalogFirestoreMirrorService
/// خدمة مخصصة لعكس وتكرار عمليات الكتالوج إلى Firestore كمصدر احتياطي متوافق
/// (Fallback Mirror) دون التأثير على نجاح المصدر المعتمد الأساسي (Back4App)
class CatalogFirestoreMirrorService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collRef =>
      _firestore.collection('catalog_products');

  /// ➕/✏️ عكس إضافة أو تحديث منتج إلى Firestore
  Future<bool> mirrorCreateOrUpdate(CatalogProduct product) async {
    final pid = product.id;
    if (pid == null || pid.isEmpty) return false;

    try {
      await _collRef.doc(pid).set(
        product.toMap(),
        SetOptions(merge: true),
      );
      debugPrint('[CATALOG_MIRROR] backend=firestore status=success productId=$pid');
      return true;
    } catch (e) {
      debugPrint('[CATALOG_MIRROR] backend=firestore status=failed productId=$pid error=$e');
      return false;
    }
  }

  /// 🗑️ عكس حذف ناعم لمنتج إلى Firestore (الحفاظ على التوافق مع Back4App Soft-Delete)
  Future<bool> mirrorDelete(String productId) async {
    if (productId.isEmpty) return false;

    try {
      final now = DateTime.now().toIso8601String();
      await _collRef.doc(productId).set({
        'status': 'deleted',
        'deleted_at': now,
        'updated_at': now,
      }, SetOptions(merge: true));
      debugPrint('[CATALOG_MIRROR] backend=firestore status=success operation=delete productId=$productId');
      return true;
    } catch (e) {
      debugPrint('[CATALOG_MIRROR] backend=firestore status=failed operation=delete productId=$productId error=$e');
      return false;
    }
  }

  /// 📦 عكس دفعة من المنتجات (Batch Mirror) مثل استيراد Excel
  Future<int> mirrorBatch(List<CatalogProduct> products, {int batchSize = 400}) async {
    if (products.isEmpty) return 0;
    int mirroredCount = 0;

    for (var i = 0; i < products.length; i += batchSize) {
      final chunk = products.sublist(
        i,
        i + batchSize > products.length ? products.length : i + batchSize,
      );

      try {
        final batch = _firestore.batch();
        for (final p in chunk) {
          final pid = p.id;
          if (pid != null && pid.isNotEmpty) {
            batch.set(_collRef.doc(pid), p.toMap(), SetOptions(merge: true));
          }
        }
        await batch.commit();
        mirroredCount += chunk.length;
        debugPrint('[CATALOG_MIRROR] backend=firestore status=success batch_chunk=${chunk.length}');
      } catch (e) {
        debugPrint('[CATALOG_MIRROR] backend=firestore status=failed batch_chunk=${chunk.length} error=$e');
      }
    }

    return mirroredCount;
  }
}
