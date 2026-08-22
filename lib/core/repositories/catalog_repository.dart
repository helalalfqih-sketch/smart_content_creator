import '../../models/catalog_product_model.dart';
import '../../models/catalog_media_model.dart';
import '../../models/catalog_category_model.dart';

/// 🏛️ CatalogRepository Interface
/// واجهة إدارة الكتالوج المستقلة عن مزود التخزين
abstract class CatalogRepository {
  /// جلب قائمة المنتجات مع تصفية وترتيب
  Future<List<CatalogProduct>> getProducts({
    int page = 1,
    int limit = 50,
    String? category,
    String? search,
    String? sortOption,
    bool forceRefresh = false,
  });

  /// جلب تفاصيل منتج واحد مع وسائطه
  Future<CatalogProduct?> getProduct(String productId);

  /// حفظ أو إنشاء منتج جديد
  Future<bool> saveProduct(CatalogProduct product);

  /// تحديث منتج موجود
  Future<bool> updateProduct(CatalogProduct product);

  /// حذف منتج (حذف ناعم لمنع عودة المنتج بعد المزامنة)
  Future<bool> deleteProduct(String productId);

  /// استعادة منتج محذوف ناعماً
  Future<bool> restoreProduct(String productId);

  /// سحب التغييرات والتحديثات من السحابة (Delta Sync)
  Future<void> syncWithServer();

  /// جلب وسائط منتج محدد
  Future<List<CatalogProductMedia>> getProductMedia(String productId);

  /// إضافة وسيط (صورة/فيديو) لمنتج
  Future<bool> addProductMedia(CatalogProductMedia media);

  /// حذف وسيط لمنتج
  Future<bool> deleteProductMedia(String mediaId);

  /// جلب قائمة الفئات
  Future<List<CatalogCategory>> getCategories();
}
