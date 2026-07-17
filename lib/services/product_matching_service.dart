import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/catalog_product_model.dart';
import '../controllers/auth_controller.dart';

/// 🏷️ تصنيفات المطابقة
enum MatchClassification {
  exactMatch,
  highSimilarity,
  possibleSimilar,
  newProduct,
}

/// 📦 نتيجة مطابقة المنتج
class ProductMatchingResult {
  final CatalogProduct product;
  final double score;
  final MatchClassification classification;
  final String reason;

  ProductMatchingResult({
    required this.product,
    required this.score,
    required this.classification,
    required this.reason,
  });
}

/// 🧠 Product Matching Service
/// خدمة برمجية لمطابقة المنتجات ومنع التكرار في الكتالوج دون استدعاء AI في المقارنة
class ProductMatchingService extends GetxService {
  
  /// 🧮 حساب التشابه النصي باستخدام معامل Jaccard بعد تصفية كلمات الربط العربية
  double calculateJaccardSimilarity(String s1, String s2) {
    if (s1.trim().isEmpty && s2.trim().isEmpty) return 1.0;
    if (s1.trim().isEmpty || s2.trim().isEmpty) return 0.0;

    final stopWords = {
      'في', 'من', 'على', 'ال', 'و', 'يا', 'عن', 'بـ', 'لـ', 'مع', 'أو', 
      'ثم', 'إلى', 'بين', 'هذا', 'هذه', 'تم', 'تمت', 'كان', 'كانت'
    };

    final regExp = RegExp(r'[^\w\s\u0600-\u06FF]');
    
    final cleanWords1 = s1.toLowerCase()
        .replaceAll(regExp, ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toSet();

    final cleanWords2 = s2.toLowerCase()
        .replaceAll(regExp, ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toSet();

    if (cleanWords1.isEmpty && cleanWords2.isEmpty) return 1.0;
    if (cleanWords1.isEmpty || cleanWords2.isEmpty) return 0.0;

    final intersection = cleanWords1.intersection(cleanWords2).length;
    final union = cleanWords1.union(cleanWords2).length;

    return intersection / union;
  }

  /// 🔎 البحث عن المطابقات والمشابهات في المنتجات الموجودة مسبقاً
  List<ProductMatchingResult> findMatches(Map<String, String> aiData, List<CatalogProduct> existingProducts) {
    final List<ProductMatchingResult> results = [];
    
    final extractedTitle = aiData['TITLE']?.trim() ?? aiData['product_name']?.trim() ?? '';
    final extractedBrand = aiData['BRAND']?.trim() ?? aiData['brand']?.trim() ?? '';
    final extractedModel = aiData['MODEL']?.trim() ?? aiData['model']?.trim() ?? '';
    final extractedBarcode = aiData['BARCODE']?.trim() ?? aiData['barcode']?.trim() ?? aiData['gtin']?.trim() ?? '';
    final extractedSku = aiData['SKU']?.trim() ?? aiData['sku']?.trim() ?? '';
    final extractedCategory = aiData['CATEGORY']?.trim() ?? aiData['category']?.trim() ?? '';
    final extractedColor = aiData['COLOR']?.trim() ?? aiData['color']?.trim() ?? '';
    final extractedSize = aiData['SIZE']?.trim() ?? aiData['size']?.trim() ?? '';

    for (final product in existingProducts) {
      // ----------------------------------------------------
      // 1️⃣ Exact Matching (المطابقة التامة) - أسبقية مطلقة
      // ----------------------------------------------------
      
      // أ) تطابق الباركود
      if (extractedBarcode.isNotEmpty && product.gtin != null && extractedBarcode == product.gtin) {
        results.add(ProductMatchingResult(
          product: product,
          score: 1.0,
          classification: MatchClassification.exactMatch,
          reason: 'تطابق تام للباركود (GTIN: $extractedBarcode)',
        ));
        continue;
      }

      // ب) تطابق الـ SKU
      if (extractedSku.isNotEmpty && product.id != null && extractedSku.toLowerCase() == product.id!.toLowerCase()) {
        results.add(ProductMatchingResult(
          product: product,
          score: 1.0,
          classification: MatchClassification.exactMatch,
          reason: 'تطابق تام للمعرف الفريد (SKU: $extractedSku)',
        ));
        continue;
      }

      // ج) تطابق الموديل والماركة معاً
      if (extractedModel.isNotEmpty && extractedBrand.isNotEmpty && 
          product.itemGroupId != null && product.brand != null &&
          extractedModel.toLowerCase() == product.itemGroupId!.toLowerCase() &&
          extractedBrand.toLowerCase() == product.brand!.toLowerCase()) {
        results.add(ProductMatchingResult(
          product: product,
          score: 0.95,
          classification: MatchClassification.exactMatch,
          reason: 'تطابق الموديل ($extractedModel) والعلامة التجارية ($extractedBrand)',
        ));
        continue;
      }

      // ----------------------------------------------------
      // 2️⃣ Rule-Based Similarity Matching (المطابقة الموزونة)
      // ----------------------------------------------------
      double score = 0.0;
      final List<String> matchReasons = [];

      // أ) تشابه الاسم (بوزن 50%)
      double titleSim = 0.0;
      if (extractedTitle.isNotEmpty && product.title.isNotEmpty) {
        titleSim = calculateJaccardSimilarity(extractedTitle, product.title);
        score += titleSim * 0.50;
        if (titleSim > 0.0) {
          matchReasons.add('تشابه الاسم بنسبة ${(titleSim * 100).toStringAsFixed(0)}%');
        }
      }

      // ب) تطابق العلامة التجارية (بوزن 20%)
      if (extractedBrand.isNotEmpty && product.brand != null) {
        if (extractedBrand.toLowerCase() == product.brand!.toLowerCase()) {
          score += 0.20;
          matchReasons.add('تطابق العلامة التجارية ($extractedBrand)');
        } else {
          // اختلاف العلامة التجارية يقلل النسبة تلقائياً لمنع الدمج الخاطئ بين الماركات
          score -= 0.30;
        }
      }

      // ج) تطابق الفئة (بوزن 15%)
      if (extractedCategory.isNotEmpty && product.categoryName != null) {
        final catLower = product.categoryName!.trim().toLowerCase();
        final extCatLower = extractedCategory.trim().toLowerCase();
        if (catLower.contains(extCatLower) || extCatLower.contains(catLower)) {
          score += 0.15;
          matchReasons.add('تطابق الفئة التجارية ($extractedCategory)');
        }
      }

      // د) تطابق المتغيرات (اللون والمقاس) (بوزن 15%)
      double attributeWeight = 0.0;
      if (extractedColor.isNotEmpty && product.color != null && extractedColor.toLowerCase() == product.color!.toLowerCase()) {
        attributeWeight += 0.075;
        matchReasons.add('تطابق اللون ($extractedColor)');
      }
      if (extractedSize.isNotEmpty && product.size != null && extractedSize.toLowerCase() == product.size!.toLowerCase()) {
        attributeWeight += 0.075;
        matchReasons.add('تطابق المقاس ($extractedSize)');
      }
      score += attributeWeight;

      // ضبط النسبة بين 0.0 و 1.0
      score = score.clamp(0.0, 1.0);

      // تصنيف النتيجة حسب النقاط الإجمالية
      if (score >= 0.85) {
        results.add(ProductMatchingResult(
          product: product,
          score: score,
          classification: MatchClassification.highSimilarity,
          reason: matchReasons.join('، '),
        ));
      } else if (score >= 0.60) {
        results.add(ProductMatchingResult(
          product: product,
          score: score,
          classification: MatchClassification.possibleSimilar,
          reason: matchReasons.join('، '),
        ));
      }
    }

    // ترتيب النتائج تنازلياً حسب النسبة الأعلى
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// 💾 حفظ قرار المطابقة في مستودع السجلات (Match History Logs)
  Future<void> saveMatchDecision({
    required String? productId,
    required String decision,
    required double similarityScore,
    required String reason,
  }) async {
    try {
      final auth = Get.find<AuthController>();
      final uid = auth.firebaseUid;
      if (uid == null) return;

      final docRef = FirebaseFirestore.instance.collection('product_match_history').doc();
      await docRef.set({
        'id': docRef.id,
        'product_id': productId,
        'user_id': uid,
        'decision': decision, // merge, update, create_new, cancel
        'similarity_score': similarityScore,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('💾 MatchHistory: Recorded decision [$decision] for product $productId (Score: $similarityScore)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MatchHistory: Error saving match decision log: $e');
      }
    }
  }
}
