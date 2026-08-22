import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../models/catalog_product_model.dart';

/// 📊 نتيجة استيراد ملف الـ Excel (XLSX)
class CatalogXlsxImportResult {
  final int totalSheetRows;
  final int headerRows;
  final int validProductsCount;
  final int invalidProductsCount;
  final List<CatalogProduct> products;

  CatalogXlsxImportResult({
    required this.totalSheetRows,
    required this.headerRows,
    required this.validProductsCount,
    required this.invalidProductsCount,
    required this.products,
  });

  @override
  String toString() {
    return 'sheet_rows_total=$totalSheetRows, header_rows=$headerRows, valid_products=$validProductsCount, invalid_products=$invalidProductsCount';
  }
}

/// 🛡️ خدمة مخصصة لاستيراد ملفات XLSX مباشرة من خلال تفكيك بنية الـ ZIP والـ XML
/// لتجاوز أخطاء التحليل الداخلية في حزم الطرف الثالث (Parser._parseTable Null Check crash)
class CatalogXlsxImportService {
  /// تحويل أحرف الأعمدة مثل 'A', 'B', 'AA' إلى فهرس رقمي يبدأ من 0
  static int _columnLetterToIndex(String colLetters) {
    int result = 0;
    for (int i = 0; i < colLetters.length; i++) {
      result = result * 26 + (colLetters.codeUnitAt(i) - 64);
    }
    return result - 1;
  }

  /// استخراج الفهرس الرقمي للعمود من مرجع الخلية (مثل "C12" -> 2)
  static int _cellRefToColIndex(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return 0;
    return _columnLetterToIndex(letters);
  }

  /// 📥 تحليل بايتات ملف XLSX واستخراج المنتجات
  static CatalogXlsxImportResult parseBytes(
    Uint8List bytes, {
    String targetSheetName = 'recovery_reference',
  }) {
    debugPrint('[CATALOG_IMPORT_VERSION] dedicated_xlsx_xml_reader_v1');

    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. قراءة النصوص المشتركة (Shared Strings) إن وجدت
    final List<String> sharedStrings = [];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final xmlDoc = XmlDocument.parse(
        utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true),
      );
      for (final si in xmlDoc.findAllElements('si')) {
        final tNodes = si.findAllElements('t');
        final text = tNodes.map((t) => t.innerText).join();
        sharedStrings.add(text);
      }
    }

    // 2. قراءة ملف العلاقات (Relationships) لتحديد مسارات أوراق العمل
    final Map<String, String> rels = {};
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels') ??
        archive.findFile('_rels/workbook.xml.rels');
    if (relsFile != null) {
      final relsDoc = XmlDocument.parse(
        utf8.decode(relsFile.content as List<int>, allowMalformed: true),
      );
      for (final rel in relsDoc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) {
          String normalized = target;
          if (normalized.startsWith('/xl/')) {
            normalized = normalized.substring(4);
          } else if (normalized.startsWith('xl/')) {
            normalized = normalized.substring(3);
          } else if (normalized.startsWith('/')) {
            normalized = normalized.substring(1);
          }
          rels[id] = 'xl/$normalized';
        }
      }
    }

    // 3. قراءة ورقة العمل المحددة من workbook.xml
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException('ملف غير صالح: xl/workbook.xml غير موجود في الأرشيف');
    }
    final wbDoc = XmlDocument.parse(
      utf8.decode(workbookFile.content as List<int>, allowMalformed: true),
    );

    String? targetSheetPath;
    final availableSheets = <String>[];
    String? firstSheetPath;

    for (final sheet in wbDoc.findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? '';
      final rId = sheet.getAttribute('r:id') ?? sheet.getAttribute('id') ?? '';
      if (name.isNotEmpty) availableSheets.add(name);

      final resolvedPath = rels[rId];
      if (firstSheetPath == null && resolvedPath != null) {
        firstSheetPath = resolvedPath;
      }

      if (name.toLowerCase() == targetSheetName.toLowerCase()) {
        targetSheetPath = resolvedPath;
      }
    }

    debugPrint('[CATALOG_IMPORT] available_sheets=$availableSheets');

    // إذا لم تكن الورقة المطلوبة موجودة، نستخدم أول ورقة مع تحذير
    if (targetSheetPath == null) {
      if (availableSheets.isEmpty || firstSheetPath == null) {
        throw FormatException(
          'لم يتم العثور على أوراق عمل صالحة في الملف. الأوراق المتاحة: ${availableSheets.join(", ")}',
        );
      }
      debugPrint('⚠️ Sheet "$targetSheetName" not found, falling back to first sheet: ${availableSheets.first}');
      targetSheetPath = firstSheetPath;
    } else {
      debugPrint('[CATALOG_IMPORT] selected_sheet=$targetSheetName');
    }

    // 4. فتح وقراءة ملف XML الخاص بالورقة
    final wsFile = archive.findFile(targetSheetPath);
    if (wsFile == null) {
      throw FormatException('ملف ورقة العمل "$targetSheetPath" غير موجود في الأرشيف');
    }

    final wsDoc = XmlDocument.parse(
      utf8.decode(wsFile.content as List<int>, allowMalformed: true),
    );
    final rowElements = wsDoc.findAllElements('row').toList();
    final totalSheetRows = rowElements.length;

    if (rowElements.isEmpty) {
      debugPrint('[CATALOG_IMPORT] selected_sheet has 0 rows');
      return CatalogXlsxImportResult(
        totalSheetRows: 0,
        headerRows: 0,
        validProductsCount: 0,
        invalidProductsCount: 0,
        products: [],
      );
    }

    // دالة مساعدة لاستخراج النص الصافي من عنصر الخلية
    String getCellText(XmlElement c) {
      final type = c.getAttribute('t');
      if (type == 's') {
        final vNode = c.findElements('v').firstOrNull;
        if (vNode != null) {
          final sIdx = int.tryParse(vNode.innerText);
          if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
            return sharedStrings[sIdx];
          }
        }
        return '';
      } else if (type == 'inlineStr') {
        final tNodes = c.findAllElements('t');
        return tNodes.map((t) => t.innerText).join();
      } else {
        final vNode = c.findElements('v').firstOrNull;
        if (vNode != null) {
          return vNode.innerText;
        }
        final tNodes = c.findAllElements('t');
        if (tNodes.isNotEmpty) {
          return tNodes.map((t) => t.innerText).join();
        }
        return '';
      }
    }

    // استخراج كافة الصفوف والخلايا إلى شبكة مرتبة بالفهرس
    final List<Map<int, String>> parsedGrid = [];
    for (final row in rowElements) {
      final Map<int, String> rowMap = {};
      for (final c in row.findAllElements('c')) {
        final r = c.getAttribute('r');
        int colIdx = 0;
        if (r != null) {
          colIdx = _cellRefToColIndex(r);
        }
        rowMap[colIdx] = getCellText(c).trim();
      }
      parsedGrid.add(rowMap);
    }

    // 5. قراءة عناوين الأعمدة من السطر الأول
    final headerRow = parsedGrid.first;
    final Map<String, int> headerMap = {};
    for (final entry in headerRow.entries) {
      final key = entry.value.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '_');
      if (key.isNotEmpty) {
        headerMap[key] = entry.key;
      }
    }

    final List<CatalogProduct> validProducts = [];
    int invalidCount = 0;

    // 6. تحويل سطور البيانات إلى نماذج CatalogProduct
    for (int i = 1; i < parsedGrid.length; i++) {
      final rowData = parsedGrid[i];

      String getVal(String colName) {
        final normalized = colName.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '_');
        final idx = headerMap[normalized];
        if (idx == null) return '';
        return rowData[idx] ?? '';
      }

      final id = getVal('id').isNotEmpty ? getVal('id') : getVal('retailer_id');
      final title = getVal('title').isNotEmpty ? getVal('title') : getVal('name');
      final description = getVal('description');
      final priceStr = getVal('price');
      final link = getVal('link');
      final imageLink = getVal('image_link').isNotEmpty ? getVal('image_link') : getVal('image');
      final additionalImageRaw = getVal('additional_image_link').isNotEmpty
          ? getVal('additional_image_link')
          : getVal('additional_images');
      final videoLink = getVal('video_link').isNotEmpty
          ? getVal('video_link')
          : (getVal('video_url').isNotEmpty ? getVal('video_url') : getVal('video'));
      final availability = getVal('availability').isNotEmpty ? getVal('availability') : 'in stock';
      final condition = getVal('condition').isNotEmpty ? getVal('condition') : 'new';
      final brand = getVal('brand').isNotEmpty ? getVal('brand') : null;
      final category = getVal('category_name').isNotEmpty
          ? getVal('category_name')
          : (getVal('category').isNotEmpty ? getVal('category') : null);

      if (title.isEmpty && id.isEmpty) {
        invalidCount++;
        continue;
      }

      // استخراج السعر والعملة
      double parsedPrice = 0.0;
      String parsedCurrency = 'YER';
      if (priceStr.isNotEmpty) {
        final cleanNumber = priceStr.replaceAll(RegExp(r'[^\d\.]'), '');
        parsedPrice = double.tryParse(cleanNumber) ?? 0.0;

        final upper = priceStr.toUpperCase();
        if (upper.contains('USD')) {
          parsedCurrency = 'USD';
        } else if (upper.contains('SAR')) {
          parsedCurrency = 'SAR';
        } else {
          parsedCurrency = 'YER';
        }
      }

      // استخراج روابط الصور الإضافية
      final List<String> additionalImages = additionalImageRaw.isNotEmpty
          ? additionalImageRaw
              .split(',')
              .map((u) => u.trim())
              .where((u) => u.startsWith('http'))
              .toList()
          : [];

      final product = CatalogProduct(
        id: id.isNotEmpty ? id : 'prd_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: title,
        description: description,
        availability: availability,
        condition: condition,
        price: parsedPrice,
        currency: parsedCurrency,
        link: link,
        imageLink: imageLink,
        additionalImageLinks: additionalImages,
        videoUrl: videoLink.isNotEmpty ? videoLink : null,
        brand: brand,
        categoryName: category,
        status: 'pending',
      );

      validProducts.add(product);
    }

    final result = CatalogXlsxImportResult(
      totalSheetRows: totalSheetRows,
      headerRows: 1,
      validProductsCount: validProducts.length,
      invalidProductsCount: invalidCount,
      products: validProducts,
    );

    debugPrint('[CATALOG_IMPORT] $result');
    return result;
  }
}
