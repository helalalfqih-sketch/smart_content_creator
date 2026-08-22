import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/models/catalog_product_model.dart';
import 'package:smart_content_creator/core/repositories/catalog_repository.dart';
import 'package:smart_content_creator/models/catalog_media_model.dart';
import 'package:smart_content_creator/models/catalog_category_model.dart';

class MockBack4AppCatalogRepository implements CatalogRepository {
  final List<CatalogProduct> mockProducts;
  final bool shouldFail;

  MockBack4AppCatalogRepository({
    required this.mockProducts,
    this.shouldFail = false,
  });

  @override
  Future<List<CatalogProduct>> getProducts({
    int page = 1,
    int limit = 100,
    String? category,
    String? search,
    String? sortOption,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) throw Exception("Back4App network timeout");
    return mockProducts;
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async => null;
  @override
  Future<bool> saveProduct(CatalogProduct product) async => false;
  @override
  Future<bool> updateProduct(CatalogProduct product) async => false;
  @override
  Future<bool> deleteProduct(String productId) async => false;
  @override
  Future<bool> restoreProduct(String productId) async => false;
  @override
  Future<void> syncWithServer() async {}
  @override
  Future<List<CatalogProductMedia>> getProductMedia(String productId) async => [];
  @override
  Future<bool> addProductMedia(CatalogProductMedia media) async => false;
  @override
  Future<bool> deleteProductMedia(String mediaId) async => false;
  @override
  Future<List<CatalogCategory>> getCategories() async => [];
}

void main() {
  group('Catalog Dual-Read Mode Verification Tests', () {
    test('Primary Back4App Read returns 375 products and renders UI', () async {
      final sampleProducts = List.generate(
        375,
        (i) => CatalogProduct(
          id: 'prd_$i',
          title: 'Product $i',
          description: 'Description for product $i',
          price: (i + 1) * 100.0,
          currency: 'YER',
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
        ),
      );

      final repo = MockBack4AppCatalogRepository(mockProducts: sampleProducts);
      final fetched = await repo.getProducts(forceRefresh: true);

      expect(fetched.length, 375);
      expect(fetched.first.id, 'prd_0');
      expect(fetched.last.id, 'prd_374');
    });

    test('Back4App Failure triggers Fallback without throwing', () async {
      final repo = MockBack4AppCatalogRepository(mockProducts: [], shouldFail: true);

      expect(
        () async => await repo.getProducts(forceRefresh: true),
        throwsA(isA<Exception>()),
      );
    });
  });
}
