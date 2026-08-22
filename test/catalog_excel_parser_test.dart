import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/models/catalog_product_model.dart';
import 'package:smart_content_creator/models/catalog_media_model.dart';

void main() {
  group('Catalog Excel & Product Model Verification', () {
    test('Parse price and currency correctly from Excel strings', () {
      final sampleRow1 = [
        'prd_123',
        'منتج تجريبي',
        'وصف المنتج',
        'in stock',
        'new',
        '18000.00 YER',
        'https://smartcontentcreator-d49f2.web.app/app/product/prd_123',
        'https://example.com/img1.jpg',
        'https://example.com/img2.jpg,https://example.com/img3.jpg',
      ];

      final product = CatalogProduct.fromExcelRow(sampleRow1, 1);
      expect(product.id, 'prd_123');
      expect(product.price, 18000.0);
      expect(product.currency, 'YER');
      expect(product.imageLink, 'https://example.com/img1.jpg');
      expect(product.additionalImageLinks.length, 2);
      expect(product.additionalImageLinks, contains('https://example.com/img2.jpg'));
    });

    test('USD and SAR Currency Detection', () {
      final usdRow = ['prd_usd', 'USD Product', 'Desc', 'in stock', 'new', '150.50 USD'];
      final sarRow = ['prd_sar', 'SAR Product', 'Desc', 'in stock', 'new', '500.00 SAR'];

      final pUsd = CatalogProduct.fromExcelRow(usdRow, 1);
      final pSar = CatalogProduct.fromExcelRow(sarRow, 2);

      expect(pUsd.currency, 'USD');
      expect(pUsd.price, 150.50);
      expect(pSar.currency, 'SAR');
      expect(pSar.price, 500.0);
    });

    test('Media DedupeKey generation matches SHA256(productId|type|url)', () {
      const pid = 'crkt9v6gx8';
      const type = 'image';
      const url = 'https://media.example.com/photo.jpg';

      final expectedHash = sha256.convert(utf8.encode('$pid|$type|$url')).toString();

      final media = CatalogProductMedia(
        productId: pid,
        type: type,
        url: url,
        dedupeKey: expectedHash,
      );

      expect(media.dedupeKey, expectedHash);
      expect(media.dedupeKey.length, 64);
    });

    test('Meta Commerce Manager CSV Header & Row generation backward compatibility', () {
      final product = CatalogProduct(
        id: 'test_sku_1',
        title: 'سماعة رأس لاسلكية',
        description: 'سماعة بلوتوث عالية الجودة',
        price: 25000.0,
        currency: 'YER',
        link: 'https://smartcontentcreator2.web.app/app/product/test_sku_1',
        imageLink: 'https://example.com/main.jpg',
        additionalImageLinks: ['https://example.com/add1.jpg', 'https://example.com/add2.jpg'],
        videoUrl: 'https://example.com/video.mp4',
        brand: 'Sony',
      );

      final csvRow = product.toCsvRow();
      expect(csvRow, contains('test_sku_1'));
      expect(csvRow, contains('25000.00 YER'));
      expect(csvRow, contains('https://example.com/main.jpg'));
      expect(csvRow, contains('https://example.com/add1.jpg'));
      expect(csvRow, contains('https://example.com/video.mp4'));
      expect(csvRow, contains('Sony'));
      expect(CatalogProduct.csvHeader, contains('additional_image_link[0]'));
    });
  });
}
