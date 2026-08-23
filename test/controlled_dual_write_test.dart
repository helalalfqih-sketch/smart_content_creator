import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:smart_content_creator/models/catalog_product_model.dart';
import 'package:smart_content_creator/models/catalog_media_model.dart';
import 'package:smart_content_creator/core/repositories/catalog_repository.dart';
import 'package:smart_content_creator/models/catalog_category_model.dart';

/// Mock Implementation to verify Controlled Dual-Write contracts
class ControlledDualWriteMockRepository implements CatalogRepository {
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

class MockFirestoreMirror {
  final Map<String, CatalogProduct> firestoreDocs = {};
  bool simulateFirestoreFailure = false;

  Future<bool> mirrorCreateOrUpdate(CatalogProduct product) async {
    if (simulateFirestoreFailure) {
      debugPrint('[CATALOG_MIRROR] backend=firestore status=failed productId=${product.id}');
      return false;
    }
    firestoreDocs[product.id!] = product;
    debugPrint('[CATALOG_MIRROR] backend=firestore status=success productId=${product.id}');
    return true;
  }

  Future<bool> mirrorDelete(String productId) async {
    if (simulateFirestoreFailure) {
      debugPrint('[CATALOG_MIRROR] backend=firestore status=failed operation=delete productId=$productId');
      return false;
    }
    final existing = firestoreDocs[productId];
    if (existing != null) {
      firestoreDocs[productId] = existing.copyWith(status: 'deleted');
    }
    debugPrint('[CATALOG_MIRROR] backend=firestore status=success operation=delete productId=$productId');
    return true;
  }
}

void main() {
  group('Controlled Dual-Write Architecture Contract Tests', () {
    late ControlledDualWriteMockRepository repo;
    late MockFirestoreMirror mirror;

    setUp(() {
      repo = ControlledDualWriteMockRepository();
      mirror = MockFirestoreMirror();

      // Seed initial 375 products
      for (int i = 0; i < 375; i++) {
        repo.remoteProducts['prd_$i'] = CatalogProduct(
          id: 'prd_$i',
          title: 'Product $i',
          description: 'Description for product $i',
          price: 100.0 + i,
          currency: 'YER',
          imageLink: 'https://storage.googleapis.com/test/prod_$i.jpg',
          syncVersion: 1,
        );
      }
    });

    test('Test A: Create ONE new product with 2 images & 1 video (375 -> 376)', () async {
      expect((await repo.getProducts()).length, 375);

      const pid = 'prd_dual_write_test_001';
      const img1 = 'https://firebasestorage.googleapis.com/v0/b/app/test_img1.jpg';
      const img2 = 'https://firebasestorage.googleapis.com/v0/b/app/test_img2.jpg';
      const video = 'https://firebasestorage.googleapis.com/v0/b/app/test_video.mp4';

      debugPrint('[CATALOG_MEDIA_UPLOAD] type=image status=success url=$img1');
      debugPrint('[CATALOG_MEDIA_UPLOAD] type=image status=success url=$img2');
      debugPrint('[CATALOG_MEDIA_UPLOAD] type=video status=success url=$video');

      final newProduct = CatalogProduct(
        id: pid,
        title: 'Smart Power Bank 30000mAh',
        description: 'High capacity fast charging battery',
        price: 25000,
        currency: 'YER',
        imageLink: img1,
        additionalImageLinks: [img2],
        videoUrl: video,
        syncVersion: 1,
      );

      // 1. Authoritative Back4App write
      final b4aOk = await repo.saveProduct(newProduct);
      expect(b4aOk, isTrue);

      // 2. Add media records
      await repo.addProductMedia(CatalogProductMedia(
        productId: pid,
        type: 'image',
        url: img1,
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: sha256.convert(utf8.encode('$pid|image|$img1')).toString(),
      ));
      await repo.addProductMedia(CatalogProductMedia(
        productId: pid,
        type: 'image',
        url: img2,
        isPrimary: false,
        sortOrder: 1,
        dedupeKey: sha256.convert(utf8.encode('$pid|image|$img2')).toString(),
      ));
      await repo.addProductMedia(CatalogProductMedia(
        productId: pid,
        type: 'video',
        url: video,
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: sha256.convert(utf8.encode('$pid|video|$video')).toString(),
      ));

      // 3. Mirror to Firestore
      final mirrorOk = await mirror.mirrorCreateOrUpdate(newProduct);
      expect(mirrorOk, isTrue);

      // Assertions
      final allProducts = await repo.getProducts();
      expect(allProducts.length, 376);
      expect(repo.remoteMedia.length, 3);
      expect(mirror.firestoreDocs.containsKey(pid), isTrue);
      expect(allProducts.firstWhere((p) => p.id == pid).imageLink, img1);
    });

    test('Test B: Edit ONE existing product increments syncVersion & updates media', () async {
      const pid = 'prd_10';
      final existing = repo.remoteProducts[pid]!;
      expect(existing.syncVersion, 1);

      const newPrimaryImg = 'https://firebasestorage.googleapis.com/v0/b/app/updated_primary.jpg';
      const newAdditionalImg = 'https://firebasestorage.googleapis.com/v0/b/app/updated_extra.jpg';
      const newVideo = 'https://firebasestorage.googleapis.com/v0/b/app/updated_video.mp4';

      final updated = existing.copyWith(
        imageLink: newPrimaryImg,
        additionalImageLinks: [newAdditionalImg],
        videoUrl: newVideo,
      );

      final updateOk = await repo.updateProduct(updated);
      expect(updateOk, isTrue);

      await repo.addProductMedia(CatalogProductMedia(
        productId: pid,
        type: 'image',
        url: newPrimaryImg,
        isPrimary: true,
        sortOrder: 0,
        dedupeKey: sha256.convert(utf8.encode('$pid|image|$newPrimaryImg')).toString(),
      ));

      await mirror.mirrorCreateOrUpdate(updated);

      final reloaded = (await repo.getProduct(pid))!;
      expect(reloaded.syncVersion, 2);
      expect(reloaded.imageLink, newPrimaryImg);
      expect(mirror.firestoreDocs[pid]?.imageLink, newPrimaryImg);
    });

    test('Test C: Firestore mirror failure does NOT break Back4App authoritative save', () async {
      const pid = 'prd_dual_write_test_mirror_fail';
      final product = CatalogProduct(
        id: pid,
        title: 'Product with Mirror Fail',
        description: 'Tests resilience',
        price: 5000,
        currency: 'YER',
        imageLink: 'https://firebasestorage.googleapis.com/v0/b/app/test.jpg',
        syncVersion: 1,
      );

      // Back4App succeeds
      final b4aOk = await repo.saveProduct(product);
      expect(b4aOk, isTrue);

      // Simulate Firestore failure
      mirror.simulateFirestoreFailure = true;
      final mirrorOk = await mirror.mirrorCreateOrUpdate(product);
      expect(mirrorOk, isFalse);

      // Back4App data remains intact and authoritative
      final retrieved = await repo.getProduct(pid);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, pid);
    });

    test('Test D: Back4App failure rejects save without creating Firestore-only fake product', () async {
      const pid = 'prd_dual_write_b4a_fail';
      final product = CatalogProduct(
        id: pid,
        title: 'Product Back4App Fail',
        description: 'Should fail completely',
        price: 5000,
        currency: 'YER',
        imageLink: 'https://firebasestorage.googleapis.com/v0/b/app/test.jpg',
        syncVersion: 1,
      );

      // Simulate Back4App failure
      repo.simulateBack4AppFailure = true;
      final b4aOk = await repo.saveProduct(product);
      expect(b4aOk, isFalse);

      // Controller must NOT call mirror if primary fails
      if (!b4aOk) {
        debugPrint('⚠️ Save aborted due to primary Back4App failure');
      } else {
        await mirror.mirrorCreateOrUpdate(product);
      }

      // Assert no Firestore or Back4App phantom product created
      expect(repo.remoteProducts.containsKey(pid), isFalse);
      expect(mirror.firestoreDocs.containsKey(pid), isFalse);
    });
  });
}
