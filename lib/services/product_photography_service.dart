import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product_photo_models.dart';
import 'gemini_service.dart';
import 'ai_image_generation_service.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../models/brand_identity_model.dart';
import 'package:flutter/services.dart';
import 'firestore_user_service.dart';
import '../controllers/auth_controller.dart';
import '../core/utils/image_utils.dart';
import 'unified_ai_service.dart';
import 'product_memory_service.dart';
import '../core/utils/json_utils.dart';

/// 🎬 خدمة التصوير الإعلاني الذكي للمنتجات
/// Intelligent Product Photography Service
///
/// تحول صور المنتجات العادية إلى صور إعلانية احترافية باستخدام:
/// 1. Gemini Vision للتحليل الذكي
/// 2. توليد سيناريوهات إبداعية
/// 3. Imagen أو بدائل لتوليد الصور
class ProductPhotographyService extends GetxService {
  final GeminiService _geminiService = GeminiService();
  final AiImageGenerationService _imageGenService = AiImageGenerationService();
  final UnifiedAIService _unifiedService = UnifiedAIService();
  SettingsController get _settings => Get.find<SettingsController>();

  /// 🧠 تحليل صورة المنتج واقتراح سيناريوهات إعلانية
  ///
  /// يستخدم المزامنة البصرية للفصل بين المنتج والقالب في سياق واحد (Integrated Context)
  Future<ProductAnalysis> analyzeProduct(File productImage, {File? templateImage}) async {
    try {
      final apiKey = _settings.getApiKey(ProviderType.gemini);
      if (apiKey.isEmpty) {
        throw Exception(
            'مفتاح Gemini API غير موجود. يرجى إضافته في الإعدادات.');
      }

      final imageBytes = await productImage.readAsBytes();

      // 1. جلب الهوية البصرية (Brand Identity Context)
      final auth = Get.find<AuthController>();
      final firestore = Get.find<FirestoreUserService>();
      final uid = auth.firebaseUid;
      BrandIdentity? brand;
      if (uid != null) {
        brand = await firestore.getBrandIdentity(uid);
      }

      final brandContext = brand != null ? """
CONTEXT: The user belongs to the brand '${brand.storeName}' in the '${brand.industry ?? 'General'}' industry. 
Provide analysis that aligns with this brand's potential style.
""" : "";

      // 🧠 Memory-First Optimization (Zero-Redundancy)
      // 🛡️ Skip ONLY if single image (no template). If template is present, force Joint Analysis.
      if (uid != null && templateImage == null) {
        final ProductMemoryService memory = Get.find<ProductMemoryService>();
        final lastMemory = await memory.getLastProduct(uid);
        
        if (lastMemory != null) {
          if (kDebugMode) debugPrint("🧠 [ProductPhoto]: Memory found for $uid! Skipping primary analysis.");
          
          return ProductAnalysis(
            productType: lastMemory.productName,
            productTypeEn: lastMemory.productNameEn ?? lastMemory.productName,
            targetAudience: "General Audience",
            idealEnvironment: lastMemory.category ?? "E-commerce Studio",
            idealEnvironmentEn: lastMemory.category ?? "E-commerce Studio",
            mood: "Professional & Clean",
            lightingType: "Cinematic Studio Lighting",
            lightingTypeEn: "Cinematic Studio Lighting",
            rawData: {
              'product_name': lastMemory.productName,
              'category': lastMemory.category,
              'source': 'memory_cache'
            },
          );
        }
      }

      // 🎬 التحليل البصري المتكامل ( Integrated Context)
      AiResult response;

      if (templateImage != null) {
        // 🚀 Integrated Vision Reasoning (Product + Template)
        if (kDebugMode) debugPrint('🍱 [Full Meal Analysis]: Product + Template...');
        final List<Uint8List> images = [
          await productImage.readAsBytes(),
          await templateImage.readAsBytes(),
        ];
        
        final String combinedPrompt = '''
$brandContext
أنت مخرج إعلانات محترف ومصور منتجات خبير. قم بتحليل هاتين الصورتين معاً كمشروع إعلاني واحد:

**الأدوار الصارمة:**
- **[الصورة 0]**: هي "البطل" (Hero Product). استخرج كل المعلومات وتحليل المنتج من هذه الصورة **فقط**.
- **[الصورة 1]**: هي "بيئة الخلفية" (Template). استخدمها فقط لفهم الجو العام، وتجاهل أي نصوص أو علامات تجارية بداخلها (مثل Alibaba Sanaa).

**مهمتك الرئيسية:**
1. **تحديد نوع المنتج**: ما هو هذا المنتج بالضبط من [الصورة 0]؟
2. **الجمهور والمزاج**: كيف يتوافق بطلنا من [الصورة 0] مع جو وتصميم القالب في [الصورة 1]؟

أرجع إجابتك كـ JSON فقط بهذا التنسيق:
{
  "product_type": "نوع المنتج بالعربية",
  "product_type_en": "Product type in English",
  "target_audience": "الجمهور المستهدف",
  "ideal_environment": "البيئة المثالية بالعربية",
  "ideal_environment_en": "Ideal environment in English",
  "mood": "المزاج المناسب",
  "category": "الفئة",
  "suggested_props": [],
  "lighting_type": "نوع الإضاءة المقترحة",
  "lighting_type_en": "Lighting type in English"
}

لا تضف أي نص خارج الـ JSON.
''';
        
        response = await _unifiedService.analyzeBatchImages(images, combinedPrompt);
      } else {
        // 🏝️ Standard Single Image Analysis (Backward Compatibility)
        final analysisPrompt = '''
$brandContext
أنت مخرج إعلانات محترف ومصور منتجات خبير. قم بتحليل صورة هذا المنتج بدقة:

**مهمتك:**
1. **تحديد نوع المنتج**: ما هو هذا المنتج بالضبط؟
2. **الجمهور المستهدف**: من هو المستخدم المثالي؟
3. **البيئة والمزاج**: ما هو الشعور الذي يجب أن تنقله الصورة؟

**مهم جداً**: أرجع إجابتك كـ JSON فقط.
''';

        response = await _geminiService.analyzeImage(
          imageBytes,
          analysisPrompt,
          apiKey: apiKey,
        );
      }

      if (kDebugMode) {
        debugPrint('🎬 Product Analysis Response: ${response.description}');
      }

      // محاولة استخراج JSON من الرد
      final Map<String, dynamic> analysisData = JsonUtils.parseSafe(response.description);
      
      // إذا فشل الـ parsing (أعاد فقط حقل text)، نستخدم fallback
      if (analysisData.length == 1 && analysisData.containsKey('text')) {
        if (kDebugMode) {
          debugPrint('⚠️ JSON parsing returned only text, using fallback analysis');
        }
        return ProductAnalysis.fromJson(_createFallbackAnalysis(response.description));
      }

      return ProductAnalysis.fromJson(analysisData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Product Analysis Error: $e');
      }
      rethrow;
    }
  }

  /// 🎨 توليد سيناريوهات متعددة بناءً على التحليل
  ///
  /// يقترح 3-5 سيناريوهات مختلفة للاختيار من بينها
  Future<List<ScenePrompt>> generateSceneOptions(
      ProductAnalysis analysis) async {
    try {
      final apiKey = _settings.getApiKey(ProviderType.gemini);
      if (apiKey.isEmpty) {
        throw Exception('مفتاح Gemini API غير موجود');
      }

      final scenesPrompt = '''
بناءً على هذا التحليل للمنتج:
- النوع: ${analysis.productType}
- الجمهور: ${analysis.targetAudience}
- البيئة: ${analysis.idealEnvironment}
- المزاج: ${analysis.mood}

اقترح 4 سيناريوهات إعلانية مختلفة ومبتكرة. كل سيناريو يجب أن يكون:
1. **فريد ومميز** عن الآخرين
2. **قابل للتنفيذ** في صورة واحدة
3. **جذاب بصرياً** ويحكي قصة

أرجع النتيجة كـ JSON Array فقط:
[
  {
    "id": "1",
    "title_ar": "عنوان السيناريو بالعربية",
    "title_en": "Scene Title in English",
    "description_ar": "وصف قصير للمشهد بالعربية",
    "prompt_en": "A professional product photograph of [PRODUCT] placed in [DETAILED SCENE DESCRIPTION]. Cinematic lighting, 8k, photorealistic, highly detailed, [STYLE KEYWORDS]",
    "style": "cinematic",
    "emoji": "🌊"
  }
]

**مهم**: 
- الـ prompt_en يجب أن يكون تفصيلي جداً بالإنجليزية
- استخدم أنماط مختلفة: cinematic, luxury, minimal, lifestyle
- كن مبدعاً في اختيار الأماكن والعناصر

لا تضف أي نص خارج الـ JSON Array.
''';

      final response = await _geminiService.generateText(
        scenesPrompt,
        apiKey: apiKey,
      );

      if (kDebugMode) {
        debugPrint('🎨 Scene Options Response: ${response.description}');
      }

      // استخراج JSON
      final List<dynamic> scenesData = JsonUtils.parseListSafe(response.description);
      
      if (scenesData.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to parse scenes JSON or empty, using fallback');
        }
        return _createFallbackScenes(analysis).map((s) => ScenePrompt.fromJson(s)).toList();
      }

      return scenesData.map((s) => ScenePrompt.fromJson(s)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Scene Generation Error: $e');
      }
      // إرجاع سيناريوهات افتراضية
      return _createFallbackScenes(analysis)
          .map((s) => ScenePrompt.fromJson(s))
          .toList();
    }
  }

  /// 📸 توليد الصورة الإعلانية النهائية
  ///
  /// يستخدم السيناريو المختار لتوليد صورة احترافية
  Future<ProductPhotoResult> generateProductPhoto({
    required File productImage,
    required ScenePrompt scenePrompt,
    ProductPhotoStyle? style,
  }) async {
    final startTime = DateTime.now();

    try {
      // في الوضع الحالي (Demo Mode)، نستخدم خدمة توليد الصور الموجودة
      final selectedStyle = style ?? scenePrompt.style;

      // تحسين البرومبت بإضافة كلمات مفتاحية للأسلوب
      final enhancedPrompt = '''
${scenePrompt.promptEn}

Style: ${selectedStyle.promptKeywords}
Quality: masterpiece, best quality, ultra detailed, 8k uhd, professional photography
''';

      if (kDebugMode) {
        debugPrint('📸 Generating image with prompt: $enhancedPrompt');
      }

      // توليد الصورة
      final result = await _imageGenService.generateImage(
        enhancedPrompt,
        style: selectedStyle.name,
      );

      final processingTime = DateTime.now().difference(startTime);

      if (result.success && result.file != null) {
        return ProductPhotoResult.successResult(
          image: result.file!,
          analysis: scenePrompt.analysis,
          prompt: scenePrompt,
          time: processingTime,
          demo: _imageGenService.demoMode,
        );
      } else {
        return ProductPhotoResult.failure(
          result.error ?? 'فشل توليد الصورة',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Photo Generation Error: $e');
      }
      return ProductPhotoResult.failure(e.toString());
    }
  }

  /// 🎯 العملية الكاملة: تحليل + سيناريوهات + توليد
  ///
  /// دالة شاملة تنفذ كل الخطوات
  Future<Map<String, dynamic>> processProductPhoto({
    required File productImage,
    File? templateImage,
    ScenePrompt? selectedScene,
  }) async {
    try {
      // 1. تحليل المنتج (مع سياق القالب إذا وجد)
      if (kDebugMode) {
        debugPrint('🔍 Step 1: Analyzing product ${templateImage != null ? "(with Context)" : ""}...');
      }
      
      final analysis = await analyzeProduct(productImage, templateImage: templateImage);

      // 2. توليد السيناريوهات
      if (kDebugMode) debugPrint('🎨 Step 2: Generating scene options...');
      final scenes = await generateSceneOptions(analysis);

      // 3. توليد الصورة (إذا تم اختيار سيناريو)
      ProductPhotoResult? photoResult;
      if (selectedScene != null) {
        if (kDebugMode) debugPrint('📸 Step 3: Generating final photo...');
        photoResult = await generateProductPhoto(
          productImage: productImage,
          scenePrompt: selectedScene,
        );
      }

      return {
        'success': true,
        'analysis': analysis,
        'scenes': scenes,
        'photo_result': photoResult,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Process Error: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🚀 توليد إعلان احترافي متكامل مع الهوية البصرية (v3.0)
  Future<ProductPhotoResult> generateBrandedMarketingAd({
    required File productImage,
    File? boxImage,
    File? templateImage,
    bool useBranding = true,
    String? customPrompt,
  }) async {
    final startTime = DateTime.now();
    try {
      final auth = Get.find<AuthController>();
      final firestore = Get.find<FirestoreUserService>();
      final uid = auth.firebaseUid;

      // 1. جلب الهوية البصرية (إذا تم تفعيلها)
      BrandIdentity? brand;
      if (useBranding && uid != null) {
        brand = await firestore.getBrandIdentity(uid);
      }

      // 1. تحليل المنتج (رؤية كمبيوتر) لضمان دقة الذاكرة والتعرف التلقائي
      if (kDebugMode) debugPrint('🔍 Step 1: Analyzing product...');
      final analysis = await analyzeProduct(productImage);

      // 2. معالجة الصور (تفريغ الخلفية)
      if (kDebugMode) debugPrint('🧹 Removing backgrounds...');
      
      final productBytes = await productImage.readAsBytes();
      Uint8List? transparentProductBytes = await _imageGenService.removeBackground(productBytes);
      
      final tempDir = await getTemporaryDirectory();
      File prodFile;
      
      if (transparentProductBytes != null) {
        prodFile = File('${tempDir.path}/prod_no_bg.png');
        await prodFile.writeAsBytes(transparentProductBytes);
      } else {
        // Fallback: Use original image if background removal fails/key is missing
        if (kDebugMode) debugPrint('⚠️ Skipping BG removal for product (No key/failed)');
        prodFile = productImage;
      }

      File? boxFile;
      if (boxImage != null) {
        final boxBytes = await boxImage.readAsBytes();
        Uint8List? transparentBoxBytes = await _imageGenService.removeBackground(boxBytes);
        
        if (transparentBoxBytes != null) {
          boxFile = File('${tempDir.path}/box_no_bg.png');
          await boxFile.writeAsBytes(transparentBoxBytes);
        } else {
          boxFile = boxImage;
        }
      }

      // 3. الدمج مع القالب (Composition)
      if (kDebugMode) debugPrint('🖌️ Creating Composite Ad...');
      
      File templateToUse;
      if (templateImage != null) {
        templateToUse = templateImage;
      } else {
        // تحميل قالب افتراضي من الأسيتس ونسخه لملف مؤقت
        final assetPath = 'assets/images/styles/WhatsApp Image 2026-03-28 at 9.14.03 PM.jpeg';
        final byteData = await rootBundle.load(assetPath);
        final templateFile = File('${tempDir.path}/default_template.jpg');
        await templateFile.writeAsBytes(byteData.buffer.asUint8List());
        templateToUse = templateFile;
      }

      File? logoFile;
      final String? logoUrl = brand?.logoUrl;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          File? rawLogoFile;
          // جلب الشعار من الرابط (إذا كان رابطاً وليس مساراً محلياً)
          if (logoUrl.startsWith('http')) {
            final dioObj = dio.Dio();
            final response = await dioObj.get<List<int>>(
              logoUrl,
              options: dio.Options(responseType: dio.ResponseType.bytes),
            );
            if (response.data != null) {
              final logoPath = '${tempDir.path}/brand_logo_${DateTime.now().millisecondsSinceEpoch}.png';
              rawLogoFile = File(logoPath);
              await rawLogoFile.writeAsBytes(response.data!);
            }
          } else if (logoUrl.isNotEmpty) {
             final f = File(logoUrl);
             if (await f.exists()) rawLogoFile = f;
          }

          // ✨ إزالة خلفية الشعار قبل الدمج (مع ميزة الحفظ الذكي للتقليل من التكلفة)
          if (rawLogoFile != null) {
            // 🧠 التحقق مما إذا كان الشعار مهيأ ومفرغ مسبقاً
            if (rawLogoFile.path.toLowerCase().contains('_nobg.png') || 
                logoUrl.toLowerCase().contains('_nobg.png')) {
              if (kDebugMode) debugPrint('⚡ استرجاع الشعار الشفاف المكتشف سابقاً من قاعدة البيانات (بدون سحب رصيد)');
              logoFile = rawLogoFile;
            } else {
              final logoBytes = await rawLogoFile.readAsBytes();
              if (kDebugMode) debugPrint('🧹 جاري إزالة خلفية الشعار لأول مرة...');
              Uint8List? transparentLogoBytes = await _imageGenService.removeBackground(logoBytes);
              
              if (transparentLogoBytes != null) {
                // حفظ الشعار المفرغ بمكان دائم لاستخدامه مستقبلاً
                final appDir = await getApplicationDocumentsDirectory();
                logoFile = File('${appDir.path}/brand_logo_nobg_${DateTime.now().millisecondsSinceEpoch}.png');
                await logoFile.writeAsBytes(transparentLogoBytes);
                if (kDebugMode) debugPrint('✅ تمت إزالة خلفية الشعار وحفظ النسخة الشفافة.');
                
                // تحديث ملف المستخدم لحفظ الشعار الدائم
                try {
                  final authController = Get.find<AuthController>();
                  final firestoreService = Get.find<FirestoreUserService>();
                  final uid = authController.firebaseUid;
                  
                  if (uid != null) {
                    final updatedBrand = brand!.copyWith(logoUrl: logoFile.path);
                    await firestoreService.saveBrandIdentity(uid: uid, brand: updatedBrand);
                    if (kDebugMode) debugPrint('💾 تم حفظ مسار الشعار الشفاف في الملف الشخصي للمستقبل!');
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('⚠️ فشل في تحديث الشعار الشفاف في الداتا بيز: $e');
                }
              } else {
                logoFile = rawLogoFile;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint("⚠️ Failed to process brand logo: $e");
        }
      }

      // 4. ✨ High-Fidelity AI Design (Creative Director AI)
      if (kDebugMode) debugPrint('🤖 Getting AI Creative vision BEFORE composition...');
      
      final String brandingInstructions = """
- Store: ${brand?.storeName ?? 'Smart Store'}
- Industry: ${brand?.industry ?? 'Real Estate / E-commerce'}
- Ad Goals: Cinematic, ultra-realistic, high contrast.
- Content: Write bold Arabic headlines and benefit-focused specs.
""";

      final aiVision = await Get.find<UnifiedAIService>().generateAdCreative(
        template: templateToUse,
        product: productImage, 
        logo: logoFile ?? templateToUse, 
        customPrompt: customPrompt ?? brandingInstructions,
        productName: analysis.productType, // 🆕 Context Injection
      );

      // 🧠 تحليل الميتاداتا من مخرج الذكاء الاصطناعي (Positioning & Layering)
      String position = 'Center';
      bool hasHand = false;
      if (aiVision.description.contains('POSITION: Left')) position = 'Left';
      if (aiVision.description.contains('POSITION: Right')) position = 'Right';
      if (aiVision.description.contains('"has_hand": true')) hasHand = true;

      final adGenerationPrompt = aiVision.description;
      if (kDebugMode) debugPrint('🎨 AI Design Metadata: Position=$position, Hand=$hasHand');

      // 5. 🖌️ الدمج الفيزيائي (Cinematic Composition)
      // نستخدم 'prodFile' و 'boxFile' اللذين تم تجهيزهما مسبقاً (مع تفريغ الخلفية)
      final compositeResult = await ImageUtils.createCompositeAd(
        templateFile: templateToUse,
        productFile: prodFile,
        boxFile: boxFile,
        logoFile: logoFile,
        handFile: hasHand ? prodFile : null,
        position: position,
      );

      if (compositeResult == null) throw Exception("فشل في دمج الصور");

      // 6. ✨ التحسين النهائي عبر Inpainting (Strict Composition Prompt)
      if (kDebugMode) debugPrint('🚀 High-Fidelity Refinement: Merging Product into Template...');
      
      // نستخدم تعليمات دمج صارمة لمنع الذكاء الاصطناعي من اختراع خلفيات (مثل المطابخ)
      final visualPrompt = "STRICT SUBJECT PRESERVATION: The product is from (Image-1). "
                          "STRICT TEMPLATE PRESERVATION: The background MUST be the *EXACT TEMPLATE* from (Image-2). "
                          "DO NOT CREATE A NEW SCENE. Do not add kitchen countertops, bedrooms, or furniture not in Image-2. "
                          "Seamlessly integrate the ${analysis.productTypeEn} into the provided environment of Image-2. "
                          "Match lighting and realistic contact shadows, professional 8k photorealistic quality.";

      if (kDebugMode) debugPrint('🚀 Sending to Stability AI for final fusion...');
      
      final result = await _imageGenService.generateInpaintingComposite(
        imageFile: compositeResult.compositeFile,
        maskFile: compositeResult.maskFile,
        prompt: visualPrompt,
      );








      final processingTime = DateTime.now().difference(startTime);

      if (result.success && result.localPath != null) {
        return ProductPhotoResult.successResult(
          image: File(result.localPath!),
          analysis: analysis,
          prompt: ScenePrompt(
            id: 'branded_ad',
            titleAr: 'إعلان احترافي مخصص',
            titleEn: 'Custom Branded Ad',
            descriptionAr: 'تم توليده بناءً على هويتك البصرية وتقنية الدمج الذكي',
            promptEn: adGenerationPrompt,
            style: ProductPhotoStyle.cinematic,
            emoji: '🏷️',
          ),
          time: processingTime,
        );
      } else {
        return ProductPhotoResult.failure(result.error ?? 'فشل توليد الإعلان');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Branded Ad Error: $e');
      return ProductPhotoResult.failure(e.toString());
    }
  }

  // ==================== Helper Methods ====================

  /// إنشاء تحليل احتياطي إذا فشل الـ JSON parsing
  Map<String, dynamic> _createFallbackAnalysis(String rawResponse) {
    return {
      'product_type': 'منتج',
      'product_type_en': 'Product',
      'target_audience': 'الجمهور العام',
      'ideal_environment': 'استوديو احترافي',
      'mood': 'احترافي وجذاب',
      'category': 'general',
      'suggested_props': [],
      'lighting_type': 'soft studio lighting',
      'raw_response': rawResponse,
    };
  }

  /// إنشاء سيناريوهات احتياطية
  List<Map<String, dynamic>> _createFallbackScenes(ProductAnalysis analysis) {
    final productName = analysis.productType;

    return [
      {
        'id': '1',
        'title_ar': 'استوديو فخم',
        'title_en': 'Premium Luxury Studio',
        'description_ar': 'إضاءة سينمائية وخلفية رخامية فاخرة',
        'prompt_en':
            'Professional product photography, the product $productName remains UNTOUCHED and IDENTICAL, placed on a dark luxury marble surface, dramatic rim lighting, cinematic shadows, masterpiece, 8k uhd, sharp focus.',
        'style': 'luxury',
        'emoji': '💎',
      },
      {
        'id': '2',
        'title_ar': 'بسيط وعصري',
        'title_en': 'Minimalist Modern',
        'description_ar': 'خلفية بيضاء نقية مع إضاءة ناعمة',
        'prompt_en':
            'A minimalist studio product photograph, $productName is PRESERVED EXACTLY, clean white background, soft diffused lighting, elegant simple composition, professional catalog style, high quality, 8k.',
        'style': 'minimal',
        'emoji': '⚪',
      },
      {
        'id': '3',
        'title_ar': 'بيئة طبيعية',
        'title_en': 'Natural Lifestyle',
        'description_ar': 'سياق واقعي مع إضاءة النهار الطبيعية',
        'prompt_en':
            'Authentic lifestyle product photograph, $productName remains UNCHANGED, placed in a natural organic setting with soft sunlight, real-world context, beautiful bokeh background, photorealistic, 8k.',
        'style': 'lifestyle',
        'emoji': '🌿',
      },
      {
        'id': '4',
        'title_ar': 'إعلان احترافي',
        'title_en': 'High-End Commercial',
        'description_ar': 'نمط إعلانات المجلات العالمية',
        'prompt_en':
            'High-end commercial product photography, strict preservation of $productName details, vibrant professional background, studio strobe lighting, razor sharp focus, high contrast, advertising style, masterpiece.',
        'style': 'cinematic',
        'emoji': '🎬',
      },
    ];
  }
}
