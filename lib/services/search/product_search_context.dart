/// 🧠 ProductSearchContext
/// كائن غني يحمل هوية المنتج الكاملة بدلاً من مجرد نص خام.
/// يُستخدم كوقود لـ PlatformQueryBuilder لتوليد استعلامات مخصصة لكل منصة.
class ProductSearchContext {
  final String originalName;
  final String englishName;
  final String chineseName;
  final String brand;
  final String model;
  final String category;
  final List<String> features;
  final List<String> searchKeywords;
  final String? imageUrl;

  const ProductSearchContext({
    required this.originalName,
    required this.englishName,
    this.chineseName = '',
    this.brand = '',
    this.model = '',
    this.category = '',
    this.features = const [],
    this.searchKeywords = const [],
    this.imageUrl,
  });

  // ─────────────────────────────────────────────────────────────
  // 🔄 تحويل من نص خام (Backward Compatible)
  // ─────────────────────────────────────────────────────────────

  /// يحوّل نصاً خاماً (مثل "Makita BP-D02 blood pressure monitor")
  /// إلى كائن ProductSearchContext بشكل تلقائي.
  factory ProductSearchContext.fromRawString(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[★✨✅📊🎬🔎📸📦🚀💡⚠️❌👁️⚡🔗🛠️✂️🎨🧠]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return const ProductSearchContext(
        originalName: '',
        englishName: '',
      );
    }

    // 🎯 استخراج رقم الموديل (مثل BP-D02, YT-M2052, 158V)
    final modelRegex = RegExp(r'\b[A-Za-z]{1,4}[-]?\d+[A-Za-z0-9]*\b');
    final modelMatch = modelRegex.firstMatch(cleaned);
    final extractedModel = modelMatch?.group(0) ?? '';

    // 🎯 استخراج الكلمات المفتاحية (أول 5 كلمات كاستعلام أساسي)
    final words = cleaned.split(RegExp(r'\s+'));
    final keywords = words.take(5).where((w) => w.length > 2).toList();

    // 🎯 تحديد البراند (الكلمة الأولى إذا كانت تبدأ بحرف كبير)
    String brand = '';
    if (words.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(words.first)) {
      brand = words.first;
    }

    return ProductSearchContext(
      originalName: cleaned,
      englishName: cleaned,
      brand: brand,
      model: extractedModel,
      searchKeywords: keywords,
    );
  }

  /// يحوّل من Map (إذا كان payload JSON)
  factory ProductSearchContext.fromMap(Map<String, dynamic> map) {
    return ProductSearchContext(
      originalName: map['originalName']?.toString() ?? map['englishName']?.toString() ?? '',
      englishName: map['englishName']?.toString() ?? '',
      chineseName: map['chineseName']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      features: List<String>.from(map['features'] ?? []),
      searchKeywords: List<String>.from(map['searchKeywords'] ?? []),
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'originalName': originalName,
        'englishName': englishName,
        'chineseName': chineseName,
        'brand': brand,
        'model': model,
        'category': category,
        'features': features,
        'searchKeywords': searchKeywords,
        'imageUrl': imageUrl,
      };

  // ─────────────────────────────────────────────────────────────
  // 🛠️ Helpers
  // ─────────────────────────────────────────────────────────────

  bool get isEmpty => englishName.isEmpty && originalName.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// الاسم الأفضل للعرض (إنجليزي أو أصلي)
  String get displayName => englishName.isNotEmpty ? englishName : originalName;

  /// استعلام البحث القصير (brand + model أو أول 4 كلمات)
  String get shortQuery {
    if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model';
    if (searchKeywords.isNotEmpty) return searchKeywords.take(4).join(' ');
    return displayName.split(' ').take(4).join(' ');
  }

  /// الاسم الصيني أو fallback بكلمات التجارة الصينية
  String get bestChineseQuery {
    if (chineseName.isNotEmpty) return chineseName;
    // Fallback: استخدام الاسم الإنجليزي (Douyin يفهمه أحياناً)
    return displayName;
  }

  @override
  String toString() => 'ProductSearchContext(en: $englishName, zh: $chineseName, brand: $brand, model: $model)';
}
