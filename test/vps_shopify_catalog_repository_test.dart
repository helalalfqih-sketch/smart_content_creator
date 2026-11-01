import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/core/repositories/vps_shopify_catalog_repository.dart';

void main() {
  test('parses a production VPS catalog page into synced products', () {
    final page = parseVpsCatalogPage(
      jsonEncode({
        'success': true,
        'page': 1,
        'totalPages': 4,
        'total': 900,
        'snapshotVersion': 'snapshot-v1',
        'data': [
          {
            'id': 'shopify:variant-20',
            'title': 'Handheld Camera',
            'description': 'Portable camera',
            'availability': 'in stock',
            'condition': 'new',
            'price': 12000,
            'salePrice': 11000,
            'currency': 'YER',
            'link': 'https://indexesstore.com/products/handheld-camera',
            'imageLink': 'https://cdn.shopify.com/camera.jpg',
            'additionalImageLinks': ['https://cdn.shopify.com/camera-side.jpg'],
            'brand': 'Indexes Store',
            'quantity': 10,
            'gtin': '0123456789012',
            'productTags': ['camera'],
            'status': 'approved',
            'syncVersion': 1,
            'updatedAt': '2026-10-31T12:00:00.000Z',
          },
        ],
      }),
    );

    expect(page.totalPages, 4);
    expect(page.products, hasLength(1));
    expect(page.products.single.id, 'shopify:variant-20');
    expect(page.products.single.title, 'Handheld Camera');
    expect(page.products.single.imageLink, contains('cdn.shopify.com'));
    expect(page.products.single.salePrice, 11000);
    expect(page.products.single.formattedSalePrice, '11000.00 YER');
    expect(page.products.single.isSynced, isTrue);
  });

  test('rejects rows without a stable Shopify identity', () {
    expect(
        () => parseVpsCatalogPage(
              jsonEncode({
                'success': true,
                'page': 1,
                'totalPages': 1,
                'total': 2,
                'snapshotVersion': 'snapshot-v1',
                'data': [
                  {'title': 'Missing id', 'price': 100},
                  {'id': 'shopify:variant-21', 'title': 'Ready', 'price': 200},
                ],
              }),
            ),
        throwsFormatException);
  });

  test('rejects unsuccessful and malformed catalog responses', () {
    expect(
      () => parseVpsCatalogPage('{"success":false,"data":[]}'),
      throwsFormatException,
    );
    expect(
      () => parseVpsCatalogPage('{"success":true,"data":{}}'),
      throwsFormatException,
    );
    expect(
      () => parseVpsCatalogPage('{"success":true,"totalPages":0,"data":[]}'),
      throwsFormatException,
    );
  });
}
