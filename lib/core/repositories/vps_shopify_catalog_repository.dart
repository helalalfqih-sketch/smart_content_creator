import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../models/catalog_category_model.dart';
import '../../models/catalog_media_model.dart';
import '../../models/catalog_product_model.dart';
import '../../services/db_service.dart';
import 'catalog_repository.dart';

@visibleForTesting
class VpsCatalogPage {
  const VpsCatalogPage({
    required this.products,
    required this.totalPages,
    required this.page,
    required this.total,
    required this.snapshotVersion,
  });

  final List<CatalogProduct> products;
  final int totalPages;
  final int page;
  final int total;
  final String snapshotVersion;
}

@visibleForTesting
VpsCatalogPage parseVpsCatalogPage(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Catalog response must be a JSON object');
  }
  if (decoded['success'] != true) {
    throw const FormatException('Catalog response was not successful');
  }

  final rawItems = decoded['data'];
  if (rawItems is! List) {
    throw const FormatException('Catalog response data must be a list');
  }
  final totalPages = decoded['totalPages'];
  final pageNumber = decoded['page'];
  final total = decoded['total'];
  final snapshotVersion = decoded['snapshotVersion'];
  if (totalPages is! int ||
      totalPages < 1 ||
      pageNumber is! int ||
      pageNumber < 1 ||
      pageNumber > totalPages ||
      total is! int ||
      total < 0 ||
      snapshotVersion is! String ||
      snapshotVersion.isEmpty) {
    throw const FormatException('Catalog pagination metadata is invalid');
  }

  final products = <CatalogProduct>[];
  for (final item in rawItems) {
    if (item is! Map) {
      throw const FormatException('Catalog product must be an object');
    }
    final product = CatalogProduct.fromMap(
      Map<String, dynamic>.from(item),
    ).copyWith(isSynced: true);
    if (product.id?.startsWith('shopify:') != true) {
      throw const FormatException('Catalog product has no Shopify identity');
    }
    products.add(product);
  }

  return VpsCatalogPage(
    products: products,
    totalPages: totalPages,
    page: pageNumber,
    total: total,
    snapshotVersion: snapshotVersion,
  );
}

/// Read-through catalog repository backed by the production VPS Shopify mirror.
///
/// Shopify credentials never leave the server. The phone receives approved,
/// active catalog rows only and keeps the existing SQLite cache for offline use.
/// This repository is intentionally read-only. Catalog administration happens
/// in Shopify until the VPS exposes an authenticated write API.
class VpsShopifyCatalogRepository implements CatalogRepository {
  VpsShopifyCatalogRepository({
    required this.dbService,
    http.Client? client,
    Uri? catalogEndpoint,
  })  : _client = client ?? http.Client(),
        _catalogEndpoint = catalogEndpoint ??
            Uri.parse('https://waha.indexesstore.com/api/catalog');

  static const int _maximumPageSize = 250;
  static const int _maximumPages = 100;

  final DBService dbService;
  final http.Client _client;
  final Uri _catalogEndpoint;

  @override
  Future<List<CatalogProduct>> getProducts({
    int page = 1,
    int limit = 50,
    String? category,
    String? search,
    String? sortOption,
    bool forceRefresh = false,
  }) async {
    final cachedProducts = await _readCachedProducts();
    if (cachedProducts.isNotEmpty && !forceRefresh) {
      unawaited(
        syncWithServer().catchError((Object error) {
          if (kDebugMode) {
            debugPrint('VPS catalog background refresh failed: $error');
          }
        }),
      );
      return _filterProducts(
        cachedProducts,
        category: category,
        search: search,
        sortOption: sortOption,
      );
    }

    try {
      final remoteProducts = await _fetchAllProducts();
      if (remoteProducts.isEmpty) {
        throw const FormatException(
          'Catalog server returned an empty production snapshot',
        );
      }
      await _replaceSyncedCache(remoteProducts);
      return _filterProducts(
        remoteProducts,
        category: category,
        search: search,
        sortOption: sortOption,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('VPS Shopify catalog refresh failed: $error');
      }
      return _filterProducts(
        cachedProducts,
        category: category,
        search: search,
        sortOption: sortOption,
      );
    }
  }

  Future<List<CatalogProduct>> _fetchAllProducts() async {
    final productsById = <String, CatalogProduct>{};
    var currentPage = 1;
    var totalPages = 1;
    String? snapshotVersion;
    int? expectedTotal;

    while (currentPage <= totalPages && currentPage <= _maximumPages) {
      final uri = _catalogEndpoint.replace(
        queryParameters: <String, String>{
          'page': currentPage.toString(),
          'limit': _maximumPageSize.toString(),
        },
      );
      final response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Catalog server returned HTTP ${response.statusCode}',
          uri,
        );
      }

      final page = parseVpsCatalogPage(response.body);
      snapshotVersion ??= page.snapshotVersion;
      expectedTotal ??= page.total;
      if (page.page != currentPage ||
          page.snapshotVersion != snapshotVersion ||
          page.total != expectedTotal ||
          (currentPage > 1 && page.totalPages != totalPages)) {
        throw const FormatException(
            'Catalog snapshot changed during pagination');
      }
      for (final product in page.products) {
        final productId = product.id?.trim() ?? '';
        if (productId.isNotEmpty) {
          productsById[productId] = product;
        }
      }

      totalPages = page.totalPages;
      if (page.products.isEmpty && currentPage < totalPages) {
        throw const FormatException('Catalog returned an incomplete page');
      }
      if (currentPage >= totalPages) break;
      currentPage += 1;
    }

    if (currentPage > _maximumPages && currentPage <= totalPages) {
      throw const FormatException(
        'Catalog pagination exceeded the safety limit',
      );
    }

    if (productsById.length != expectedTotal) {
      throw const FormatException(
          'Catalog product count does not match snapshot');
    }
    return productsById.values.toList();
  }

  Future<void> _replaceSyncedCache(
    List<CatalogProduct> remoteProducts,
  ) async {
    final remoteIds = remoteProducts
        .map((product) => product.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final database = await dbService.db;
    await database.transaction((transaction) async {
      final syncedRows = await transaction.query(
        'catalog_products',
        columns: const <String>['id'],
        where: 'is_synced = 1 AND deleted_at IS NULL',
      );
      final staleIds = syncedRows
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && !remoteIds.contains(id))
          .toList();

      final batch = transaction.batch();
      for (final product in remoteProducts) {
        batch.insert(
          'catalog_products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var offset = 0; offset < staleIds.length; offset += 50) {
        final chunk = staleIds.skip(offset).take(50).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        batch.delete(
          'catalog_products',
          where: 'id IN ($placeholders) AND is_synced = 1',
          whereArgs: chunk,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<CatalogProduct>> _readCachedProducts() async {
    final rows = await dbService.getRecords(
      'catalog_products',
      where: "is_synced = 1 AND id LIKE 'shopify:%' AND deleted_at IS NULL",
      orderBy: 'updated_at DESC',
    );
    return rows.map(CatalogProduct.fromMap).toList();
  }

  List<CatalogProduct> _filterProducts(
    List<CatalogProduct> input, {
    String? category,
    String? search,
    String? sortOption,
  }) {
    var products = input.toList();
    final normalizedSearch = search?.trim().toLowerCase() ?? '';
    if (normalizedSearch.isNotEmpty) {
      products = products.where((product) {
        return product.title.toLowerCase().contains(normalizedSearch) ||
            product.description.toLowerCase().contains(normalizedSearch) ||
            (product.brand?.toLowerCase().contains(normalizedSearch) ?? false);
      }).toList();
    }

    final normalizedCategory = category?.trim() ?? '';
    if (normalizedCategory.isNotEmpty && normalizedCategory != 'الكل') {
      products = products.where((product) {
        return product.resolvedCategoryName == normalizedCategory;
      }).toList();
    }

    switch (sortOption) {
      case 'price_asc':
        products.sort((first, second) => first.price.compareTo(second.price));
      case 'price_desc':
        products.sort((first, second) => second.price.compareTo(first.price));
      case 'created_asc':
        products.sort((first, second) {
          final firstDate =
              first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final secondDate =
              second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return firstDate.compareTo(secondDate);
        });
      default:
        products.sort((first, second) {
          final firstDate = first.updatedAt ?? first.createdAt;
          final secondDate = second.updatedAt ?? second.createdAt;
          return (secondDate ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(firstDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
    }

    return products;
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async {
    final cached = await dbService.getRecord(
      'catalog_products',
      where: 'id = ? AND is_synced = 1 AND deleted_at IS NULL',
      whereArgs: <Object>[productId],
    );
    if (cached != null) return CatalogProduct.fromMap(cached);

    final refreshed = await getProducts(forceRefresh: true);
    for (final product in refreshed) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  Future<void> syncWithServer() async {
    await getProducts(forceRefresh: true, limit: _maximumPageSize);
  }

  @override
  Future<bool> saveProduct(CatalogProduct product) async => false;

  @override
  Future<bool> updateProduct(CatalogProduct product) async => false;

  @override
  Future<bool> deleteProduct(String productId) async => false;

  @override
  Future<bool> restoreProduct(String productId) async => false;

  @override
  Future<List<CatalogProductMedia>> getProductMedia(String productId) async =>
      const <CatalogProductMedia>[];

  @override
  Future<bool> addProductMedia(CatalogProductMedia media) async => false;

  @override
  Future<bool> deleteProductMedia(String mediaId) async => false;

  @override
  Future<int> batchSaveProducts(
    List<CatalogProduct> products, {
    int batchSize = 25,
  }) async =>
      0;

  @override
  Future<List<CatalogCategory>> getCategories() async =>
      const <CatalogCategory>[];
}
