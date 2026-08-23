import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/catalog_product_model.dart';
import '../../models/catalog_media_model.dart';
import '../../models/catalog_category_model.dart';
import '../../services/db_service.dart';
import 'catalog_repository.dart';

/// 🏛️ Back4AppCatalogRepository
/// تطبيق مستودع الكتالوج المعتمد على Back4App مع التخزين المؤقت في SQLite وطابور المزامنة بدون اتصال
class Back4AppCatalogRepository implements CatalogRepository {
  final DBService dbService;
  final Future<String?> Function() getFirebaseIdToken;
  final String? Function() getCurrentUid;

  static const String _parseAppId = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
  static const String _parseRestKey = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
  static const String _parseBaseUrl = "https://parseapi.back4app.com";

  Back4AppCatalogRepository({
    required this.dbService,
    required this.getFirebaseIdToken,
    required this.getCurrentUid,
  });

  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'Content-Type': 'application/json',
  };

  @override
  Future<List<CatalogProduct>> getProducts({
    int page = 1,
    int limit = 100,
    String? category,
    String? search,
    String? sortOption,
    bool forceRefresh = false,
  }) async {
    // 1️⃣ قراءة فورية من التخزين المؤقت المحلي (SQLite Offline-First)
    final localRows = await dbService.getRecords(
      'catalog_products',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );

    List<CatalogProduct> cachedProducts = localRows
        .map((r) => CatalogProduct.fromMap(r))
        .toList();

    // إذا كانت البيانات متوفرة محلياً ولم يُطلب تحديث قسري، أرجع الكاش وابدأ التحديث في الخلفية
    if (cachedProducts.isNotEmpty && !forceRefresh) {
      // مزامنة غير متزامنة في الخلفية
      syncWithServer().catchError((e) {
        if (kDebugMode) debugPrint('⚠️ Background catalog sync error: $e');
      });
      return cachedProducts;
    }

    // 2️⃣ جلب كافة الصفحات بالتتالي من Back4App Cloud Code
    try {
      final token = await getFirebaseIdToken();
      int currentPage = page;
      int totalPages = 1;
      int serverTotal = 0;
      final List<CatalogProduct> allFetchedProducts = [];

      while (currentPage <= totalPages) {
        final body = {
          'page': currentPage,
          'limit': limit,
          'category': category,
          'search': search,
          if (token != null) 'firebaseIdToken': token,
        };

        final response = await http.post(
          Uri.parse('$_parseBaseUrl/functions/catalogList'),
          headers: _headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          final resultObj = decoded['result'] ?? {};
          final data = resultObj['data'] as List? ?? [];

          serverTotal = resultObj['total'] as int? ?? data.length;
          totalPages = resultObj['totalPages'] as int? ?? 1;

          debugPrint('[CATALOG_PAGE] page=$currentPage count=${data.length}');

          final pageProducts = data
              .map((item) => CatalogProduct.fromMap(Map<String, dynamic>.from(item)).copyWith(isSynced: true))
              .toList();

          allFetchedProducts.addAll(pageProducts);

          if (currentPage >= totalPages || data.isEmpty) {
            break;
          }
          currentPage++;
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ catalogList returned HTTP ${response.statusCode}: ${response.body}');
          }
          break;
        }
      }

      if (allFetchedProducts.isNotEmpty) {
        // إزالة التكرار بالمعرف
        final Map<String, CatalogProduct> dedupedMap = {};
        for (final p in allFetchedProducts) {
          final key = p.id ?? '';
          if (key.isNotEmpty) {
            dedupedMap[key] = p.copyWith(isSynced: true);
          }
        }
        final dedupedProducts = dedupedMap.values.toList();

        debugPrint('[CATALOG_TOTAL] server=$serverTotal fetched=${dedupedProducts.length}');

        if (dedupedProducts.length != serverTotal && serverTotal > 0) {
          debugPrint('⚠️ [CATALOG_SYNC_WARNING] fetched (${dedupedProducts.length}) != server total ($serverTotal)');
        }

        // تحديث وتوحيد SQLite لمنع انحراف العدد (Reconcile SQLite cache with authoritative server products)
        try {
          final localRows = await dbService.getRecords(
            'catalog_products',
            where: 'deleted_at IS NULL',
          );
          final serverIdSet = dedupedProducts
              .map((p) => p.id ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

          final staleIds = localRows
              .map((r) => r['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty && !serverIdSet.contains(id))
              .toList();

          if (staleIds.isNotEmpty) {
            for (int i = 0; i < staleIds.length; i += 50) {
              final chunk = staleIds.skip(i).take(50).map((id) => "'$id'").join(',');
              await dbService.deleteRecord(
                'catalog_products',
                where: 'id IN ($chunk)',
                whereArgs: const [],
              );
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ SQLite reconciliation error: $e');
        }

        await dbService.batchInsertRecords(
          'catalog_products',
          dedupedProducts.map((p) => p.toMap()).toList(),
        );

        return dedupedProducts;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to fetch cloud products: $e');
    }

    return cachedProducts;
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async {
    // 1. تحقق من الكاش المحلي
    final local = await dbService.getRecord(
      'catalog_products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (local != null) {
      return CatalogProduct.fromMap(local);
    }

    // 2. جلب من السحابة
    try {
      final token = await getFirebaseIdToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogGet'),
        headers: _headers,
        body: json.encode({
          'productId': productId,
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final pData = decoded['result']?['product'];
        if (pData != null) {
          final product = CatalogProduct.fromMap(Map<String, dynamic>.from(pData));
          await dbService.insertRecord('catalog_products', product.toMap());
          return product;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ getProduct error: $e');
    }
    return null;
  }

  @override
  Future<bool> saveProduct(CatalogProduct product) async {
    final now = DateTime.now();
    final pid = product.id?.isNotEmpty == true
        ? product.id!
        : 'prd_${now.millisecondsSinceEpoch}';

    final toSave = product.copyWith(
      id: pid,
      createdAt: product.createdAt ?? now,
      updatedAt: now,
      creatorUid: product.creatorUid ?? getCurrentUid() ?? 'helal_admin',
    );

    try {
      final token = await getFirebaseIdToken();
      final body = {
        'productId': pid,
        'retailerId': pid,
        'title': toSave.title,
        'description': toSave.description,
        'availability': toSave.availability,
        'condition': toSave.condition,
        'price': toSave.price,
        'currency': toSave.currency,
        'link': toSave.link,
        'imageLink': toSave.imageLink,
        'additionalImageLinks': toSave.additionalImageLinks,
        'videoUrl': toSave.videoUrl,
        'brand': toSave.brand,
        'googleProductCategory': toSave.googleProductCategory,
        'fbProductCategory': toSave.fbProductCategory,
        'categoryId': toSave.categoryId,
        'categoryName': toSave.categoryName,
        'metaProductType': toSave.metaProductType,
        'quantity': toSave.quantity,
        'salePrice': toSave.salePrice,
        'salePriceEffectiveDate': toSave.salePriceEffectiveDate,
        'itemGroupId': toSave.itemGroupId,
        'gender': toSave.gender,
        'color': toSave.color,
        'size': toSave.size,
        'ageGroup': toSave.ageGroup,
        'material': toSave.material,
        'pattern': toSave.pattern,
        'shipping': toSave.shipping,
        'shippingWeight': toSave.shippingWeight,
        'gtin': toSave.gtin,
        'productTags': toSave.productTags,
        'style': toSave.style,
        'status': toSave.status,
        'scope': 'global',
        'source': 'app',
        if (token != null) 'firebaseIdToken': token,
      };

      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogCreate'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['result']?['success'] == true) {
          debugPrint('[CATALOG_WRITE] backend=back4app operation=create productId=$pid');
          await dbService.insertRecord('catalog_products', toSave.toMap());
          return true;
        }
      }

      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=create productId=$pid status=${response.statusCode} error=${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=create productId=$pid exception=$e');
      return false;
    }
  }

  @override
  Future<bool> updateProduct(CatalogProduct product) async {
    if (product.id == null || product.id!.isEmpty) return false;
    final pid = product.id!;
    final now = DateTime.now();
    final toUpdate = product.copyWith(updatedAt: now);

    try {
      final token = await getFirebaseIdToken();
      final body = {
        'productId': pid,
        'title': toUpdate.title,
        'description': toUpdate.description,
        'availability': toUpdate.availability,
        'condition': toUpdate.condition,
        'price': toUpdate.price,
        'currency': toUpdate.currency,
        'link': toUpdate.link,
        'imageLink': toUpdate.imageLink,
        'additionalImageLinks': toUpdate.additionalImageLinks,
        'videoUrl': toUpdate.videoUrl,
        'brand': toUpdate.brand,
        'googleProductCategory': toUpdate.googleProductCategory,
        'fbProductCategory': toUpdate.fbProductCategory,
        'categoryId': toUpdate.categoryId,
        'categoryName': toUpdate.categoryName,
        'metaProductType': toUpdate.metaProductType,
        'quantity': toUpdate.quantity,
        'salePrice': toUpdate.salePrice,
        'salePriceEffectiveDate': toUpdate.salePriceEffectiveDate,
        'itemGroupId': toUpdate.itemGroupId,
        'gender': toUpdate.gender,
        'color': toUpdate.color,
        'size': toUpdate.size,
        'ageGroup': toUpdate.ageGroup,
        'material': toUpdate.material,
        'pattern': toUpdate.pattern,
        'shipping': toUpdate.shipping,
        'shippingWeight': toUpdate.shippingWeight,
        'gtin': toUpdate.gtin,
        'productTags': toUpdate.productTags,
        'style': toUpdate.style,
        'status': toUpdate.status,
        'expectedSyncVersion': product.syncVersion,
        if (token != null) 'firebaseIdToken': token,
      };

      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogUpdate'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['result']?['success'] == true) {
          debugPrint('[CATALOG_WRITE] backend=back4app operation=update productId=$pid');
          await dbService.updateRecord(
            'catalog_products',
            toUpdate.copyWith(syncVersion: product.syncVersion + 1).toMap(),
            where: 'id = ?',
            whereArgs: [pid],
          );
          return true;
        }
      }

      if (response.statusCode == 409) {
        debugPrint('⚠️ [CATALOG_WRITE] Optimistic lock conflict (409) updating product $pid: ${response.body}');
      } else {
        debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=update productId=$pid status=${response.statusCode} error=${response.body}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=update productId=$pid exception=$e');
      return false;
    }
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    if (productId.isEmpty) return false;
    final now = DateTime.now();

    try {
      final token = await getFirebaseIdToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogDelete'),
        headers: _headers,
        body: json.encode({
          'productId': productId,
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[CATALOG_WRITE] backend=back4app operation=delete productId=$productId');
        await dbService.updateRecord('catalog_products', {
          'status': 'deleted',
          'deleted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }, where: 'id = ?', whereArgs: [productId]);
        return true;
      }

      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=delete productId=$productId error=${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=delete productId=$productId exception=$e');
      return false;
    }
  }

  @override
  Future<bool> restoreProduct(String productId) async {
    if (productId.isEmpty) return false;
    final now = DateTime.now();

    try {
      final token = await getFirebaseIdToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogRestore'),
        headers: _headers,
        body: json.encode({
          'productId': productId,
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[CATALOG_WRITE] backend=back4app operation=restore productId=$productId');
        await dbService.updateRecord('catalog_products', {
          'status': 'approved',
          'deleted_at': null,
          'updated_at': now.toIso8601String(),
        }, where: 'id = ?', whereArgs: [productId]);
        return true;
      }

      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=restore productId=$productId error=${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=restore productId=$productId exception=$e');
      return false;
    }
  }

  @override
  Future<void> syncWithServer() async {
    // 1. إفراغ طابور العمليات المعلقة أولاً (Push local changes)
    await _drainSyncQueue();

    // 2. سحب التحديثات الجديدة من السحابة (Pull cloud changes)
    try {
      final token = await getFirebaseIdToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogPullChanges'),
        headers: _headers,
        body: json.encode({
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final items = decoded['result']?['items'] as List? ?? [];
        for (final item in items) {
          final p = CatalogProduct.fromMap(Map<String, dynamic>.from(item));
          await dbService.insertRecord('catalog_products', p.toMap());
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ syncWithServer pull error: $e');
    }
  }

  /// إفراغ طابور المزامنة بدون اتصال (Drain Sync Queue)
  Future<void> _drainSyncQueue() async {
    final pending = await dbService.getRecords(
      'catalog_sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
      limit: 20,
    );

    if (pending.isEmpty) return;
    final token = await getFirebaseIdToken();

    for (final item in pending) {
      final id = item['id'];
      final op = item['operation'];
      final payloadStr = item['payload_json'] as String? ?? '{}';
      final payload = json.decode(payloadStr);

      String endpoint = 'catalogCreate';
      if (op == 'update') {
        endpoint = 'catalogUpdate';
      } else if (op == 'delete') {
        endpoint = 'catalogDelete';
      } else if (op == 'restore') {
        endpoint = 'catalogRestore';
      }

      try {
        final body = {
          ...payload,
          if (token != null) 'firebaseIdToken': token,
        };

        final res = await http.post(
          Uri.parse('$_parseBaseUrl/functions/$endpoint'),
          headers: _headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          await dbService.deleteRecord('catalog_sync_queue', where: 'id = ?', whereArgs: [id]);
        } else {
          await dbService.updateRecord('catalog_sync_queue', {
            'retry_count': (item['retry_count'] as int? ?? 0) + 1,
            'last_error': res.body,
            'updated_at': DateTime.now().toIso8601String(),
          }, where: 'id = ?', whereArgs: [id]);
        }
      } catch (e) {
        await dbService.updateRecord('catalog_sync_queue', {
          'retry_count': (item['retry_count'] as int? ?? 0) + 1,
          'last_error': e.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  @override
  Future<List<CatalogProductMedia>> getProductMedia(String productId) async {
    final local = await dbService.getRecords(
      'catalog_product_media',
      where: 'product_id = ? AND status = ?',
      whereArgs: [productId, 'active'],
      orderBy: 'is_primary DESC, sort_order ASC',
    );

    if (local.isNotEmpty) {
      return local.map((m) => CatalogProductMedia.fromMap(m)).toList();
    }

    try {
      final token = await getFirebaseIdToken();
      final res = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogMediaList'),
        headers: _headers,
        body: json.encode({
          'productId': productId,
          if (token != null) 'firebaseIdToken': token,
        }),
      );

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final list = decoded['result']?['media'] as List? ?? [];
        final parsed = list.map((m) => CatalogProductMedia.fromMap(Map<String, dynamic>.from(m))).toList();
        for (final m in parsed) {
          await dbService.insertRecord('catalog_product_media', m.toMap());
        }
        return parsed;
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<bool> addProductMedia(CatalogProductMedia media) async {
    final dedupeKey = media.dedupeKey.isNotEmpty
        ? media.dedupeKey
        : sha256.convert(utf8.encode('${media.productId}|${media.type}|${media.url}')).toString();

    final toSave = media.copyWith(dedupeKey: dedupeKey);
    await dbService.insertRecord('catalog_product_media', toSave.toMap());

    try {
      final token = await getFirebaseIdToken();
      final res = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogMediaAdd'),
        headers: _headers,
        body: json.encode({
          'productId': toSave.productId,
          'type': toSave.type,
          'url': toSave.url,
          'thumbnailUrl': toSave.thumbnailUrl,
          'mimeType': toSave.mimeType,
          'filename': toSave.filename,
          'sortOrder': toSave.sortOrder,
          'isPrimary': toSave.isPrimary,
          'source': toSave.source,
          'status': toSave.status,
          'width': toSave.width,
          'height': toSave.height,
          'durationMs': toSave.durationMs,
          'dedupeKey': toSave.dedupeKey,
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        debugPrint('[CATALOG_MEDIA_ADD] type=${toSave.type} primary=${toSave.isPrimary} url=${toSave.url}');
        return true;
      } else {
        debugPrint('⚠️ [CATALOG_MEDIA_ADD] Server responded ${res.statusCode}: ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [CATALOG_MEDIA_ADD] exception: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteProductMedia(String mediaId) async {
    await dbService.updateRecord('catalog_product_media', {
      'status': 'deleted',
    }, where: 'id = ?', whereArgs: [mediaId]);
    return true;
  }

  @override
  Future<int> batchSaveProducts(List<CatalogProduct> products, {int batchSize = 25}) async {
    if (products.isEmpty) return 0;
    int savedCount = 0;

    for (var i = 0; i < products.length; i += batchSize) {
      final chunk = products.sublist(
        i,
        i + batchSize > products.length ? products.length : i + batchSize,
      );

      final results = await Future.wait(chunk.map((p) => saveProduct(p)));
      savedCount += results.where((r) => r == true).length;
    }

    return savedCount;
  }

  @override
  Future<List<CatalogCategory>> getCategories() async {
    try {
      final res = await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogCategoriesList'),
        headers: _headers,
        body: '{}',
      );
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final list = decoded['result']?['categories'] as List? ?? [];
        return list.map((c) => CatalogCategory.fromMap(Map<String, dynamic>.from(c))).toList();
      }
    } catch (_) {}
    return [];
  }
}
