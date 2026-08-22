// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/services/catalog_xlsx_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Catalog Media Audit', () {
  const filePath = r'C:\Users\MC\Downloads\meta_catalog_import.xlsx';
  final file = File(filePath);
  if (!file.existsSync()) {
    print('File not found');
    return;
  }

  final bytes = file.readAsBytesSync();
  final result = CatalogXlsxImportService.parseBytes(bytes);
  final products = result.products;

  int whatsappCdnCount = 0;
  int persistentCount = 0;
  int noImageCount = 0;
  int hasAdditionalImages = 0;
  int hasVideoUrl = 0;
  int totalAdditionalImages = 0;
  int whatsappAdditionalImages = 0;

  for (final p in products) {
    if (p.imageLink.isEmpty) {
      noImageCount++;
    } else if (p.imageLink.contains('cdn.whatsapp.net')) {
      whatsappCdnCount++;
    } else {
      persistentCount++;
    }

    if (p.additionalImageLinks.isNotEmpty) {
      hasAdditionalImages++;
      totalAdditionalImages += p.additionalImageLinks.length;
      whatsappAdditionalImages += p.additionalImageLinks.where((img) => img.contains('cdn.whatsapp.net')).length;
    }

    if (p.videoUrl != null && p.videoUrl!.trim().isNotEmpty) {
      hasVideoUrl++;
    }
  }

  print('=== 📊 CATALOG MEDIA AUDIT (375 Products) ===');
  print('Total Products: ${products.length}');
  print('Primary Image:');
  print('  - WhatsApp CDN (temporary/expired token): $whatsappCdnCount');
  print('  - Persistent/Other: $persistentCount');
  print('  - No Image: $noImageCount');
  print('Additional Images:');
  print('  - Products with additional images: $hasAdditionalImages');
  print('  - Total additional images: $totalAdditionalImages');
  print('  - WhatsApp CDN additional images: $whatsappAdditionalImages');
  print('Videos:');
  print('  - Products with video link: $hasVideoUrl');
  });
}
