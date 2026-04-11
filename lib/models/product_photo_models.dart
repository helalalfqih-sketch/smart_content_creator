import 'dart:io';

/// 🎬 نماذج بيانات نظام التصوير الإعلاني للمنتجات
/// Product Photography System Data Models

/// 📊 نتيجة تحليل المنتج
class ProductAnalysis {
  final String productType; // نوع المنتج (عطر، حذاء، قهوة، إلخ)
  final String productTypeEn; // Product type in English
  final String targetAudience; // الجمهور المستهدف
  final String idealEnvironment; // البيئة المثالية
  final String idealEnvironmentEn; // Ideal environment in English
  final String mood; // المزاج/الجو المناسب
  final String lightingType; // نوع الإضاءة المقترحة
  final String lightingTypeEn; // Lighting type in English
  final Map<String, dynamic> rawData; // البيانات الخام من Gemini

  ProductAnalysis({
    required this.productType,
    required this.productTypeEn,
    required this.targetAudience,
    required this.idealEnvironment,
    required this.idealEnvironmentEn,
    required this.mood,
    required this.lightingType,
    required this.lightingTypeEn,
    required this.rawData,
  });

  factory ProductAnalysis.fromJson(Map<String, dynamic> json) {
    return ProductAnalysis(
      productType: json['product_type'] ?? json['productType'] ?? 'Unknown',
      productTypeEn: json['product_type_en'] ?? json['productTypeEn'] ?? 'Product',
      targetAudience:
          json['target_audience'] ?? json['targetAudience'] ?? 'General',
      idealEnvironment:
          json['ideal_environment'] ?? json['idealEnvironment'] ?? 'Studio',
      idealEnvironmentEn:
          json['ideal_environment_en'] ?? json['idealEnvironmentEn'] ?? 'Professional studio',
      mood: json['mood'] ?? 'Professional',
      lightingType: json['lighting_type'] ?? json['lightingType'] ?? 'Soft lighting',
      lightingTypeEn: json['lighting_type_en'] ?? json['lightingTypeEn'] ?? 'cinematic lighting',
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_type': productType,
        'product_type_en': productTypeEn,
        'target_audience': targetAudience,
        'ideal_environment': idealEnvironment,
        'ideal_environment_en': idealEnvironmentEn,
        'mood': mood,
        'lighting_type': lightingType,
        'lighting_type_en': lightingTypeEn,
        'raw_data': rawData,
      };
}



/// 🎨 سيناريو مقترح للمشهد الإعلاني
class ScenePrompt {
  final String id;
  final String titleAr; // العنوان بالعربية
  final String titleEn; // العنوان بالإنجليزية
  final String promptEn; // البرومبت الكامل للتوليد (إنجليزي)
  final String descriptionAr; // الوصف للمستخدم (عربي)
  final ProductPhotoStyle style;
  final String? previewUrl; // صورة مثال (اختياري)
  final String emoji; // إيموجي للتمييز
  final ProductAnalysis? analysis; // التحليل المرتبط (اختياري)

  ScenePrompt({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.promptEn,
    required this.descriptionAr,
    required this.style,
    this.previewUrl,
    this.emoji = '🎬',
    this.analysis,
  });

  factory ScenePrompt.fromJson(Map<String, dynamic> json) {
    return ScenePrompt(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      titleAr: json['title_ar'] ?? json['titleAr'] ?? 'سيناريو مخصص',
      titleEn: json['title_en'] ?? json['titleEn'] ?? 'Custom Scene',
      promptEn: json['prompt_en'] ?? json['promptEn'] ?? json['prompt'] ?? '',
      descriptionAr: json['description_ar'] ?? json['descriptionAr'] ?? '',
      style: ProductPhotoStyle.values.firstWhere(
        (s) => s.name == (json['style'] ?? 'cinematic'),
        orElse: () => ProductPhotoStyle.cinematic,
      ),
      previewUrl: json['preview_url'] ?? json['previewUrl'],
      emoji: json['emoji'] ?? '🎬',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title_ar': titleAr,
        'title_en': titleEn,
        'prompt_en': promptEn,
        'description_ar': descriptionAr,
        'style': style.name,
        'preview_url': previewUrl,
        'emoji': emoji,
      };
}

/// 📸 نتيجة توليد الصورة الإعلانية
class ProductPhotoResult {
  final bool success;
  final File? generatedImage;
  final ProductAnalysis? analysis;
  final ScenePrompt? usedPrompt;
  final String? error;
  final Duration? processingTime;
  final bool isDemoMode; // هل تم التوليد في وضع التجربة؟

  ProductPhotoResult({
    required this.success,
    this.generatedImage,
    this.analysis,
    this.usedPrompt,
    this.error,
    this.processingTime,
    this.isDemoMode = false,
  });

  /// نسخة فاشلة مع رسالة خطأ
  factory ProductPhotoResult.failure(String error) {
    return ProductPhotoResult(
      success: false,
      error: error,
    );
  }

  /// نسخة ناجحة
  factory ProductPhotoResult.successResult({
    required File image,
    ProductAnalysis? analysis,
    ScenePrompt? prompt,
    Duration? time,
    bool demo = false,
  }) {
    return ProductPhotoResult(
      success: true,
      generatedImage: image,
      analysis: analysis,
      usedPrompt: prompt,
      processingTime: time,
      isDemoMode: demo,
    );
  }
}

/// 🎨 أنماط الصور الإعلانية
enum ProductPhotoStyle {
  cinematic, // سينمائي - إضاءة درامية
  minimal, // بسيط - خلفية نظيفة
  luxury, // فاخر - أناقة وفخامة
  lifestyle, // نمط حياة - سياق استخدام حقيقي
  studio, // استوديو - احترافي ومباشر
  natural, // طبيعي - إضاءة طبيعية وبيئة عضوية
}

extension ProductPhotoStyleExtension on ProductPhotoStyle {
  /// الاسم بالعربية
  String get nameAr {
    switch (this) {
      case ProductPhotoStyle.cinematic:
        return 'سينمائي';
      case ProductPhotoStyle.minimal:
        return 'بسيط';
      case ProductPhotoStyle.luxury:
        return 'فاخر';
      case ProductPhotoStyle.lifestyle:
        return 'نمط حياة';
      case ProductPhotoStyle.studio:
        return 'استوديو';
      case ProductPhotoStyle.natural:
        return 'طبيعي';
    }
  }

  /// الوصف بالعربية
  String get descriptionAr {
    switch (this) {
      case ProductPhotoStyle.cinematic:
        return 'إضاءة درامية وتكوين سينمائي';
      case ProductPhotoStyle.minimal:
        return 'خلفية نظيفة وبسيطة';
      case ProductPhotoStyle.luxury:
        return 'أناقة وفخامة راقية';
      case ProductPhotoStyle.lifestyle:
        return 'سياق استخدام حقيقي';
      case ProductPhotoStyle.studio:
        return 'احترافي ومباشر';
      case ProductPhotoStyle.natural:
        return 'إضاءة طبيعية وبيئة عضوية';
    }
  }

  /// الإيموجي المميز
  String get emoji {
    switch (this) {
      case ProductPhotoStyle.cinematic:
        return '🎬';
      case ProductPhotoStyle.minimal:
        return '⚪';
      case ProductPhotoStyle.luxury:
        return '💎';
      case ProductPhotoStyle.lifestyle:
        return '🏡';
      case ProductPhotoStyle.studio:
        return '📸';
      case ProductPhotoStyle.natural:
        return '🌿';
    }
  }

  /// الكلمات المفتاحية للبرومبت
  String get promptKeywords {
    switch (this) {
      case ProductPhotoStyle.cinematic:
        return 'cinematic lighting, dramatic composition, film grain, 35mm photography, depth of field, professional color grading';
      case ProductPhotoStyle.minimal:
        return 'minimal background, clean composition, soft lighting, simple elegant, white or neutral backdrop';
      case ProductPhotoStyle.luxury:
        return 'luxury setting, premium materials, elegant composition, sophisticated lighting, high-end photography';
      case ProductPhotoStyle.lifestyle:
        return 'lifestyle photography, natural setting, authentic context, real-world usage, relatable environment';
      case ProductPhotoStyle.studio:
        return 'studio photography, professional lighting, clean background, commercial product shot, high quality';
      case ProductPhotoStyle.natural:
        return 'natural lighting, organic environment, soft shadows, authentic atmosphere, daylight photography';
    }
  }
}
