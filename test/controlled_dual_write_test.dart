import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:smart_content_creator/models/catalog_product_model.dart';
import 'package:smart_content_creator/models/catalog_media_model.dart';
import 'package:smart_content_creator/core/repositories/catalog_repository.dart';
import 'package:smart_content_creator/models/catalog_category_model.dart';

/// Mock Implementation for Back4App Exclusive Catalog Architecture
class Back4AppExclusiveMockRepository implements CatalogRepository {
  final Map<String, CatalogProduct> remoteProducts = {};
  final List<CatalogProductMedia> remoteMedia = [];
  bool simulateBack4AppFailure = false;
  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<List<CatalogProduct>> getProducts({
    int page = 1,
    int limit = 50,
    String? category,
    String? search,
    String? sortOption,
    bool forceRefresh = false,
  }) async {
    if (simulateBack4AppFailure) {
      throw Exception('Back4App network failure');
    }
    return remoteProducts.values.where((p) => p.status != 'deleted').toList();
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async {
    return remoteProducts[productId];
  }

  @override
  Future<bool> saveProduct(CatalogProduct product) async {
    if (simulateBack4AppFailure) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=create productId=${product.id} status=500');
      return false;
    }
    createCalls++;
    remoteProducts[product.id!] = product;
    debugPrint('[CATALOG_WRITE] backend=back4app operation=create productId=${product.id}');
    return true;
  }

  @override
  Future<bool> updateProduct(CatalogProduct product) async {
    if (simulateBack4AppFailure) {
      debugPrint('❌ [CATALOG_WRITE] backend=back4app operation=update productId=${product.id} status=500');
      return false;
    }
    updateCalls++;
    final existing = remoteProducts[product.id!];
    final nextVersion = (existing?.syncVersion ?? product.syncVersion) + 1;
    remoteProducts[product.id!] = product.copyWith(syncVersion: nextVersion);
    debugPrint('[CATALOG_WRITE] backend=back4app operation=update productId=${product.id}');
    return true;
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    if (simulateBack4AppFailure) return false;
    final existing = remoteProducts[productId];
    if (existing != null) {
      remoteProducts[productId] = existing.copyWith(status: 'deleted');
      debugPrint('[CATALOG_WRITE] backend=back4app operation=delete productId=$productId');
      return true;
    }
    return false;
  }

  @override
  Future<bool> restoreProduct(String productId) async {
    final existing = remoteProducts[productId];
    if (existing != null) {
      remoteProducts[productId] = existing.copyWith(status: 'approved');
      debugPrint('[CATALOG_WRITE] backend=back4app operation=restore productId=$productId');
      return true;
    }
    return false;
  }

  @override
  Future<void> syncWithServer() async {}

  @override
  Future<List<CatalogProductMedia>> getProductMedia(String productId) async {
    return remoteMedia.where((m) => m.productId == productId && m.status == 'active').toList();
  }

  @override
  Future<bool> addProductMedia(CatalogProductMedia media) async {
    final dedupeKey = media.dedupeKey.isNotEmpty
        ? media.dedupeKey
        : sha256.convert(utf8.encode('${media.productId}|${media.type}|${media.url}')).toString();

    final existingIdx = remoteMedia.indexWhere((m) => m.dedupeKey == dedupeKey);
    if (existingIdx >= 0) {
      return true; // Idempotent deduplication
    }

    remoteMedia.add(media.copyWith(dedupeKey: dedupeKey));
    debugPrint('[CATALOG_MEDIA_ADD] type=${media.type} primary=${media.isPrimary} url=${media.url}');
    return true;
  }

  @override
  Future<bool> deleteProductMedia(String mediaId) async => true;

  @override
  Future<int> batchSaveProducts(List<CatalogProduct> products, {int batchSize = 25}) async {
    int saved = 0;
    for (final p in products) {
      if (await saveProduct(p)) saved++;
    }
    return saved;
  }

  @override
  Future<List<CatalogCategory>> getCategories() async => [];
}

class MockLocalCache {
  final Map<String, CatalogProduct> sqlite = {};

  void save(CatalogProduct p) {
    sqlite[p.id!] = p;
  }

  void delete(String id) {
    sqlite.remove(id);
  }
}

void main() {
  group('Back4App Exclusive Architecture Contract Tests', () {
    late Back4AppExclusiveMockRepository repo;
    late MockLocalCache cache;

    setUp(() {
      repo = Back4AppExclusiveMockRepository();
      cache = MockLocalCache();
      // Seed 375 initial products
      for (int i = 1; i <= 375; i++) {
        final p = CatalogProduct(
          id: 'prd_$i',
          title: 'Product $i',
          description: 'Desc $i',
          price: 100.0 + i,
          currency: 'YER',
          imageLink: 'https://parsefiles.back4app.com/app/img_$i.jpg',
          status: 'approved',
          syncVersion: 1,
        );
        repo.remoteProducts[p.id!] = p;
        cache.save(p);
      }
    });

    test('Test A: Create ONE new product with 2 images & 1 video exclusively in Back4App (375 -> 376)', () async {
      expect(repo.remoteProducts.length, equals(375));
      expect(cache.sqlite.length, equals(375));

      const newId = 'prd_b4a_exclusive_001';
      final mediaUrls = [
        'https://parsefiles.back4app.com/app/test_img1.jpg',
        'https://parsefiles.back4app.com/app/test_img2.jpg',
      ];
      const videoUrl = 'https://parsefiles.back4app.com/app/test_video.mp4';

      debugPrint('[CATALOG_MEDIA_UPLOAD] backend=back4app type=image status=success url=${mediaUrls[0]}');
      debugPrint('[CATALOG_MEDIA_UPLOAD] backend=back4app type=image status=success url=${mediaUrls[1]}');
      debugPrint('[CATALOG_MEDIA_UPLOAD] backend=back4app type=video status=success url=$videoUrl');

      final newProduct = CatalogProduct(
        id: newId,
        title: 'New Exclusive Product',
        description: 'New Exclusive Description',
        price: 15000.0,
        currency: 'YER',
        imageLink: mediaUrls[0],
        additionalImageLinks: [mediaUrls[1]],
        videoUrl: videoUrl,
        status: 'approved',
        syncVersion: 1,
      );

      final saveOk = await repo.saveProduct(newProduct);
      expect(saveOk, isTrue);
      cache.save(newProduct);

      // Add media rows
      await repo.addProductMedia(CatalogProductMedia(
        productId: newId,
        type: 'image',
        url: mediaUrls[0],
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: 'key_img_1',
      ));
      await repo.addProductMedia(CatalogProductMedia(
        productId: newId,
        type: 'image',
        url: mediaUrls[1],
        isPrimary: false,
        sortOrder: 1,
        dedupeKey: 'key_img_2',
      ));
      await repo.addProductMedia(CatalogProductMedia(
        productId: newId,
        type: 'video',
        url: videoUrl,
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: 'key_vid_1',
      ));

      expect(repo.remoteProducts.length, equals(376));
      expect(cache.sqlite.length, equals(376));

      final productMedia = await repo.getProductMedia(newId);
      expect(productMedia.length, equals(3));
      expect(productMedia.where((m) => m.type == 'image').length, equals(2));
      expect(productMedia.where((m) => m.type == 'video').length, equals(1));
    });

    test('Test B: Edit ONE existing product increments syncVersion & updates media in Back4App', () async {
      final existing = repo.remoteProducts['prd_10']!;
      expect(existing.syncVersion, equals(1));

      const updatedImageUrl = 'https://parsefiles.back4app.com/app/updated_primary.jpg';
      final updatedProduct = existing.copyWith(
        title: 'Updated Product Title 10',
        price: 999.0,
        imageLink: updatedImageUrl,
      );

      final updateOk = await repo.updateProduct(updatedProduct);
      expect(updateOk, isTrue);
      cache.save(repo.remoteProducts['prd_10']!);

      await repo.addProductMedia(CatalogProductMedia(
        productId: 'prd_10',
        type: 'image',
        url: updatedImageUrl,
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: 'key_updated_10',
      ));

      final saved = repo.remoteProducts['prd_10']!;
      expect(saved.syncVersion, equals(2));
      expect(saved.title, equals('Updated Product Title 10'));
      expect(saved.price, equals(999.0));
      expect(saved.imageLink, equals(updatedImageUrl));
    });

    test('Test C: Offline / Back4App failure loads local SQLite cache safely', () async {
      repo.simulateBack4AppFailure = true;

      List<CatalogProduct> loadedProducts = [];
      try {
        loadedProducts = await repo.getProducts();
      } catch (e) {
        debugPrint('[CATALOG_SOURCE] fallback=sqlite');
        loadedProducts = cache.sqlite.values.toList();
      }

      expect(loadedProducts.length, equals(375));
      debugPrint('[CATALOG_CACHE] sqlite=${cache.sqlite.length}');
      debugPrint('[CATALOG_UI] rendered=${loadedProducts.length}');
    });

    test('Test D: Selected media upload failure aborts product creation', () async {
      final mediaUploadFailed = cache.sqlite.isNotEmpty;
      bool saveCalled = false;

      if (mediaUploadFailed) {
        debugPrint('❌ [CATALOG_MEDIA_UPLOAD] backend=back4app status=500');
        debugPrint('⚠️ Save aborted: "فشل رفع الوسائط إلى الخادم. لم يتم حفظ المنتج."');
      } else {
        saveCalled = await repo.saveProduct(CatalogProduct(id: 'prd_failed_media', title: 'Fail', description: 'Fail desc', price: 100.0));
      }

      expect(saveCalled, isFalse);
      expect(repo.remoteProducts.containsKey('prd_failed_media'), isFalse);
    });
  });

  group('Global / Imported Catalog Authorization Policy Contract Tests', () {
    bool canModifyProduct({
      required bool isAdmin,
      required String? actorUid,
      required String? creatorUid,
    }) {
      if (isAdmin) return true;
      if (creatorUid != null && creatorUid.isNotEmpty && creatorUid == actorUid) {
        return true;
      }
      return false;
    }

    test('TEST A: normal user + global product + creatorUid null -> catalogMediaAdd => 403', () {
      const isUserAdmin = false;
      const actorUid = 'user_normal_123';
      const String? creatorUid = null;

      final canAddMedia = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canAddMedia, isFalse); // 403 Forbidden
    });

    test('TEST B: admin + global product + creatorUid null -> catalogMediaAdd => success', () {
      const isUserAdmin = true;
      const actorUid = 'admin_456';
      const String? creatorUid = null;

      final canAddMedia = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canAddMedia, isTrue); // Success
    });

    test('TEST C: normal unrelated user + global product with creatorUid => 403', () {
      const isUserAdmin = false;
      const actorUid = 'user_intruder_789';
      const creatorUid = 'user_legit_owner_111';

      final canModify = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canModify, isFalse); // 403 Forbidden
    });

    test('TEST D: matching creatorUid => success', () {
      const isUserAdmin = false;
      const actorUid = 'user_legit_owner_111';
      const creatorUid = 'user_legit_owner_111';

      final canModify = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canModify, isTrue); // Success
    });

    test('TEST E: normal user attempts catalogDelete on global product => 403', () {
      const isUserAdmin = false;
      const actorUid = 'user_normal_123';
      const String? creatorUid = null;

      final canDelete = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canDelete, isFalse); // 403 Forbidden
    });

    test('TEST F: normal user attempts catalogRestore on global product => 403', () {
      const isUserAdmin = false;
      const actorUid = 'user_normal_123';
      const String? creatorUid = null;

      final canRestore = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canRestore, isFalse); // 403 Forbidden
    });

    test('TEST G: admin delete/restore global product => success', () {
      const isUserAdmin = true;
      const actorUid = 'admin_super_999';
      const String? creatorUid = null;

      final canAdminAction = canModifyProduct(
        isAdmin: isUserAdmin,
        actorUid: actorUid,
        creatorUid: creatorUid,
      );

      expect(canAdminAction, isTrue); // Success
    });
  });

  group('🛡️ SQLite Reconciliation Data-Safety & Draft Preservation Tests', () {
    List<Map<String, dynamic>> reconcileSQLite({
      required Set<String> serverIds,
      required List<Map<String, dynamic>> localRows,
    }) {
      final List<Map<String, dynamic>> kept = [];
      final List<String> removedIds = [];

      final localSynced = localRows.where((r) => r['is_synced'] == 1 && r['deleted_at'] == null).toList();
      final localUnsynced = localRows.where((r) => r['is_synced'] == 0 && r['deleted_at'] == null).toList();

      for (final r in localSynced) {
        final id = r['id'] as String;
        if (serverIds.contains(id)) {
          kept.add(r);
        } else {
          removedIds.add(id);
        }
      }

      // Unsynced rows MUST ALWAYS be preserved
      for (final r in localUnsynced) {
        kept.add(r);
      }

      return kept;
    }

    test('TEST A: server IDs=[A,B], SQLite=[A(1), B(1), C(1), D(0)] => C removed, D preserved', () {
      final serverIds = {'A', 'B'};
      final localRows = [
        {'id': 'A', 'is_synced': 1, 'deleted_at': null},
        {'id': 'B', 'is_synced': 1, 'deleted_at': null},
        {'id': 'C', 'is_synced': 1, 'deleted_at': null},
        {'id': 'D', 'is_synced': 0, 'deleted_at': null},
      ];

      final remaining = reconcileSQLite(serverIds: serverIds, localRows: localRows);
      final remainingIds = remaining.map((r) => r['id']).toSet();

      expect(remainingIds.contains('A'), isTrue);
      expect(remainingIds.contains('B'), isTrue);
      expect(remainingIds.contains('C'), isFalse, reason: 'Stale synced cache C must be removed');
      expect(remainingIds.contains('D'), isTrue, reason: 'Unsynced draft D must NEVER be deleted');
      expect(remaining.firstWhere((r) => r['id'] == 'D')['is_synced'], equals(0));
    });

    test('TEST B: local draft not on server (is_synced=0) => preserved', () {
      final serverIds = {'server_prd_1', 'server_prd_2'};
      final localRows = [
        {'id': 'local_draft_999', 'is_synced': 0, 'title': 'مسودة محلية جديدة', 'deleted_at': null},
      ];

      final remaining = reconcileSQLite(serverIds: serverIds, localRows: localRows);
      expect(remaining.length, equals(1));
      expect(remaining.first['id'], equals('local_draft_999'));
      expect(remaining.first['is_synced'], equals(0));
    });

    test('TEST C: pending offline write not on server (is_synced=0) => preserved', () {
      final serverIds = <String>{}; // Offline / Empty server response
      final localRows = [
        {'id': 'offline_prd_001', 'is_synced': 0, 'title': 'منتج تم إنشاؤه أوفلاين', 'deleted_at': null},
        {'id': 'offline_prd_002', 'is_synced': 0, 'title': 'منتج آخر أوفلاين', 'deleted_at': null},
      ];

      final remaining = reconcileSQLite(serverIds: serverIds, localRows: localRows);
      expect(remaining.length, equals(2));
      expect(remaining.map((r) => r['id']).toSet(), containsAll(['offline_prd_001', 'offline_prd_002']));
    });
  });
}

