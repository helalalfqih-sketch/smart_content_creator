import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../ai/core/agent_models.dart';
import '../../controllers/auth_controller.dart';
import '../ai_backend_router.dart';
import '../product_memory_service.dart';
import '../firestore_user_service.dart';
import '../../models/brand_identity_model.dart';
import '../../controllers/settings_controller.dart';
import '../../core/utils/json_utils.dart';

class VisionProductService extends GetxService {
  AIBackendRouter get _router => Get.find<AIBackendRouter>();
  ProductMemoryService get _productMemoryService =>
      Get.find<ProductMemoryService>();
  FirestoreUserService get _firestoreService => Get.find<FirestoreUserService>();

  /// 🧠 تحليل ذكي باستخدام رؤية Gemini عبر AIBackendRouter
  Future<ProductVisionResult> analyzeImage(File image, {BrandIdentity? brand, dio.CancelToken? cancelToken}) async {
    try {
      // 1. فحص مبدئي سريع (اسم الملف) - للأداء فقط ولا يُعتمد عليه وحده (Naive Check)
      final name = image.path.toLowerCase();
      final heuristicsFound = ['watch', 'bag', 'perfume', 'shoes', 'phone']
          .any((k) => name.contains(k));

      // 2. جلب الهوية البصرية (Brand Identity Context) - Support passed brand
      BrandIdentity? resolvedBrand = brand;
      if (resolvedBrand == null) {
        String? userId;
        if (Get.isRegistered<AuthController>()) {
          final auth = Get.find<AuthController>();
          userId = auth.firebaseUid;
        }
        if (userId != null) {
          resolvedBrand = await _firestoreService.getBrandIdentity(userId);
        }
      }

      // 3. تحليل الذكاء الاصطناعي الحقيقي (AI Analysis) عبر AIBackendRouter
      final brandContext = resolvedBrand != null ? """
CONTEXT: The user belongs to the brand '${resolvedBrand.storeName}'. 
If the product in the image looks like it belongs to this brand or category (${resolvedBrand.industry}), please prioritize identifying it as such.
""" : "";

      final prompt = """
$brandContext
You are an expert visual analyst. Analyze the image and extract details.
CRITICAL: Distinguish between a commercial product (for sale) and a personal item/person (selfie, person wearing clothes, casual photo).

Return ONLY JSON:
{
  "name": "Specific product name OR visual description (e.g., 'Person wearing grey shawl')",
  "category": "Category (Electronics, Fashion, Person, Home, Selfie, Food)",
  "brand": "Brand or 'Unknown'",
  "is_commercial": true/false,
  "search_query": "Detailed English search query including [Brand] [Product Name] [Model] for best search results",
  "description": "Brief description in Arabic",
  "teaser": "A smart, unique marketing teaser or friendly comment in Arabic based SPECIFICALLY on this image (Max 15 words)"
}
NO MARKDOWN. NO EXTRA TEXT.
""";

      final bytes = await image.readAsBytes();
      final visionResponse = await _router.analyzeProductVision(
        prompt: prompt,
        imageBytes: bytes,
        mimeType: 'image/jpeg',
      );

      final rawText = visionResponse['data']?.toString() ?? '';
      final Map<String, dynamic> info = JsonUtils.parseSafe(rawText);
      info['provider'] = visionResponse['meta']?['provider'] ?? 'firebase_ai';

      // إذا أعاد الذكاء الاصطناعي اسماً صالحاً، فهو غالباً منتج
      bool isProduct = heuristicsFound;
      String? productName = heuristicsFound ? name : null;
      Map<String, dynamic> data = {};

      if (info.containsKey('name') && info['name'] != null && info['name'].toString().isNotEmpty) {
        String n = info['name'].toString().trim();
        // 🛡️ Guard against generic names
        if ([
          'product',
          'item',
          'device',
          'object',
          'undefined',
          'null',
          'منتج',
          'جهاز',
          'عنصر'
        ].contains(n.toLowerCase())) {
          // Fallback to search_query if available and specific
          if (info['search_query'] != null &&
              info['search_query'].toString().length > 5) {
            n = info['search_query'];
          } else {
            // Last resort: describe visually
            n = "Unknown Product (${info['category'] ?? 'General'})";
          }
        }

        isProduct = true;
        productName = n;
        data = info;
        if (info.containsKey('provider') && info['provider'] != null) {
          final prov = info['provider'].toString();
          if (Get.isRegistered<SettingsController>()) {
            Get.find<SettingsController>().updateLastImageProvider(prov);
          }
        }
        
        if (kDebugMode) {
          debugPrint('🔍 VisionProductService: Extracted Product: $productName');
          debugPrint('🔍 VisionProductService: Full Info: $info');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ VisionProductService: No product name found in AI response');
          debugPrint('⚠️ VisionProductService: Final Info returned: $info');
        }
      }

      final result = ProductVisionResult(
        isProduct: isProduct,
        productName: productName,
        confidence: isProduct ? 0.95 : 0.0,
        data: data,
      );

      // 🧠 حفظ المنتج في الذاكرة بعد التحليل الناجح
      if (isProduct && productName != null) {
        try {
          String userId = 'default_user';
          if (Get.isRegistered<AuthController>()) {
            final auth = Get.find<AuthController>();
            userId = auth.firebaseUid ??
                auth.user?['id']?.toString() ??
                'default_user';
          }

          // 🛡️ Normalize data before saving (remove N/A, Null, etc.)
          String? normalize(dynamic value) {
            if (value == null) {
              return null;
            }
            final s = value.toString().trim();
            final lower = s.toLowerCase();
            if (lower.isEmpty) return null;
            if ([
              'n/a',
              'unknown',
              'none',
              'null',
              'undefined',
              'not available',
              'non available',
              'this',
              'this product',
              'generic',
              'item',
              'object',
              'غير معروف',
              'لا يوجد',
              'غير متوفر',
              'غير متاح',
              'لم يتم التعرف',
              'منتج',
              'عنصر'
            ].any((p) => lower == p || lower.contains(p))) {
              return null;
            }
            return s;
          }

          final normBrand = normalize(data['brand']);
          final normModel = normalize(data['model']);
          final normBrandEn = normalize(data['brand_en']) ?? normBrand;

          await _productMemoryService.saveProductMemory(
            userId: userId,
            productName: productName,
            productNameEn: normalize(data['search_query']),
            brandName: normBrand,
            brandNameEn: normBrandEn,
            category: normalize(data['category']),
            model: normModel,
            searchQuery: normalize(data['search_query']) ?? productName,
            imagePath: image.path,
          );

          if (kDebugMode) {
            debugPrint('✅ VisionProductService: Product saved to memory');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ VisionProductService: Failed to save product to memory: $e');
          }
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ VisionProductService.analyzeImage error: $e');
      }
      return ProductVisionResult(isProduct: false, confidence: 0.0);
    }
  }

  /// 🚀 البيع الذكي: اقتراح خطوات تالية بناءً على نوع المنتج (Smart Upselling)
  List<Map<String, String>> analyzePotentialUpsells(
      ProductVisionResult result) {
    if (!result.isProduct) return [];

    final List<Map<String, String>> upsells = [];
    final name = result.productName?.toLowerCase() ?? "";

    // 1. الهوية البصرية (الشعار/العلامة التجارية) (Visual Identity)
    upsells.add({
      "title": "تصميم هوية بصرية",
      "subtitle": "شعار وألوان لنشاطك التجاري",
      "action_payload": "أريد تصميم هوية بصرية لمنتج $name"
    });

    // 2. التسويق بالفيديو (تيك توك) (Video Marketing)
    upsells.add({
      "title": "فيديو تيك توك إعلاني",
      "subtitle": "سكريبت + مشهد تخيلي",
      "action_payload": "اكتب لي سكريبت فيديو تيك توك لمنتج $name"
    });

    // 3. منطق خاص (Specific Logic)
    if (name.contains('coffee') ||
        name.contains('cafe') ||
        name.contains('قهوة')) {
      upsells.add({
        "title": "قائمة مشروبات (Menu)",
        "subtitle": "تصميم مني لعروض الصيف",
        "action_payload": "اقترح لي تصميم مني لمشروع قهوة"
      });
    }

    return upsells;
  }
}
