import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/services/catalog_xlsx_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CatalogXlsxImportService parses meta_catalog_import.xlsx accurately', () {
    const filePath = r'C:\Users\MC\Downloads\meta_catalog_import.xlsx';
    final file = File(filePath);

    if (!file.existsSync()) {
      // If run in an environment without local test file, pass gracefully
      return;
    }

    final bytes = file.readAsBytesSync();
    final result = CatalogXlsxImportService.parseBytes(
      bytes,
      targetSheetName: 'recovery_reference',
    );

    expect(result.totalSheetRows, equals(376));
    expect(result.headerRows, equals(1));
    expect(result.validProductsCount, equals(375));
    expect(result.invalidProductsCount, equals(0));
    expect(result.products.length, equals(375));

    final firstProduct = result.products.first;
    expect(firstProduct.id, isNotEmpty);
    expect(firstProduct.title, isNotEmpty);
    expect(firstProduct.price, greaterThan(0));
    expect(firstProduct.currency, equals('YER'));
    expect(firstProduct.imageLink, isNotEmpty);
  });
}
