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
  final String? Function() getFirebaseIdToken;
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

    // 2️⃣ جلب من Back4App Cloud Code
    try {
      final token = getFirebaseIdToken();
      final body = {
        'page': page,
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
        final data = decoded['result']?['data'] as List? ?? [];
        final cloudProducts = data
            .map((item) => CatalogProduct.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        // تحديث SQLite
        for (final p in cloudProducts) {
          await dbService.insertRecord('catalog_products', p.toMap());
        }

        return cloudProducts;
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
      final token = getFirebaseIdToken();
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

    // 1. حفظ فوري في SQLite
    await dbService.insertRecord('catalog_products', toSave.toMap());

    // 2. إضافة إلى طابور المزامنة المحلي
    await dbService.insertRecord('catalog_sync_queue', {
      'product_id': pid,
      'operation': 'create',
      'payload_json': json.encode(toSave.toMap()),
      'retry_count': 0,
      'status': 'pending',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // 3. محاولة المزامنة الفورية مع السحابة
    _drainSyncQueue().catchError((e) {
      if (kDebugMode) debugPrint('⚠️ Instant sync error: $e');
    });

    return true;
  }

  @override
  Future<bool> updateProduct(CatalogProduct product) async {
    if (product.id == null) return false;
    final now = DateTime.now();

    final toUpdate = product.copyWith(updatedAt: now);
    await dbService.updateRecord('catalog_products', toUpdate.toMap(), where: 'id = ?', whereArgs: [product.id]);

    await dbService.insertRecord('catalog_sync_queue', {
      'product_id': product.id!,
      'operation': 'update',
      'payload_json': json.encode(toUpdate.toMap()),
      'retry_count': 0,
      'status': 'pending',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    _drainSyncQueue().catchError((_) {});
    return true;
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    final now = DateTime.now();

    // حذف ناعم في SQLite
    await dbService.updateRecord('catalog_products', {
      'status': 'deleted',
      'deleted_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, where: 'id = ?', whereArgs: [productId]);

    await dbService.insertRecord('catalog_sync_queue', {
      'product_id': productId,
      'operation': 'delete',
      'payload_json': json.encode({'productId': productId}),
      'retry_count': 0,
      'status': 'pending',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    _drainSyncQueue().catchError((_) {});
    return true;
  }

  @override
  Future<bool> restoreProduct(String productId) async {
    final now = DateTime.now();

    await dbService.updateRecord('catalog_products', {
      'status': 'approved',
      'deleted_at': null,
      'updated_at': now.toIso8601String(),
    }, where: 'id = ?', whereArgs: [productId]);

    await dbService.insertRecord('catalog_sync_queue', {
      'product_id': productId,
      'operation': 'restore',
      'payload_json': json.encode({'productId': productId}),
      'retry_count': 0,
      'status': 'pending',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    _drainSyncQueue().catchError((_) {});
    return true;
  }

  @override
  Future<void> syncWithServer() async {
    // 1. إفراغ طابور العمليات المعلقة أولاً (Push local changes)
    await _drainSyncQueue();

    // 2. سحب التحديثات الجديدة من السحابة (Pull cloud changes)
    try {
      final token = getFirebaseIdToken();
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
    final token = getFirebaseIdToken();

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
      final token = getFirebaseIdToken();
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

    final token = getFirebaseIdToken();
    try {
      await http.post(
        Uri.parse('$_parseBaseUrl/functions/catalogMediaAdd'),
        headers: _headers,
        body: json.encode({
          ...toSave.toMap(),
          if (token != null) 'firebaseIdToken': token,
        }),
      );
    } catch (_) {}

    return true;
  }

  @override
  Future<bool> deleteProductMedia(String mediaId) async {
    await dbService.updateRecord('catalog_product_media', {
      'status': 'deleted',
    }, where: 'id = ?', whereArgs: [mediaId]);
    return true;
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
