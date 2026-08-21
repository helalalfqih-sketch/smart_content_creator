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
  /// إلى كائن ProductSearchContext بشكل تلقائي ونظيف.
  factory ProductSearchContext.fromRawString(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'[★✨✅📊🎬🔎📸📦🚀💡⚠️❌👁️⚡🔗🛠️✂️🎨🧠]'), '')
        .trim();

    // إزالة العبارات الوصفية الزائدة والضوضاء
    cleaned = cleaned
        .replaceAll(RegExp(r'\b(unknown brand|brand unknown|model unknown|unknown model|unknown)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(with silicone teeth|lavender purple|handheld|rechargeable)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
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

    // 🎯 استخراج الكلمات المفتاحية
    final words = cleaned.split(RegExp(r'\s+'));
    final keywords = words.take(5).where((w) => w.length > 2).toList();

    // 🎯 تحديد البراند (تجاهل كلمة Unknown أو الكلمات العامة)
    String brand = '';
    if (words.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(words.first)) {
      final first = words.first;
      if (!['Unknown', 'Product', 'Item', 'Device', 'Generic', 'The', 'New'].contains(first)) {
        brand = first;
      }
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
    final rawBrand = map['brand']?.toString() ?? '';
    final cleanBrand = (rawBrand.toLowerCase().contains('unknown') ||
            rawBrand.toLowerCase() == 'n/a' ||
            rawBrand.toLowerCase() == 'none')
        ? ''
        : rawBrand;

    final rawModel = map['model']?.toString() ?? '';
    final cleanModel = (rawModel.toLowerCase().contains('unknown') ||
            rawModel.toLowerCase() == 'n/a' ||
            rawModel.toLowerCase() == 'none')
        ? ''
        : rawModel;

    return ProductSearchContext(
      originalName: map['originalName']?.toString() ?? map['englishName']?.toString() ?? map['name']?.toString() ?? '',
      englishName: map['englishName']?.toString() ?? map['search_query']?.toString() ?? map['name']?.toString() ?? '',
      chineseName: map['chineseName']?.toString() ?? map['chinese_name']?.toString() ?? '',
      brand: cleanBrand,
      model: cleanModel,
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
  // 🛠️ Helpers & Chinese Keyword Generator
  // ─────────────────────────────────────────────────────────────

  bool get isEmpty => englishName.isEmpty && originalName.isEmpty && chineseName.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// الاسم الأفضل للعرض
  String get displayName {
    final name = englishName.isNotEmpty ? englishName : originalName;
    return _cleanNoise(name);
  }

  /// استعلام البحث القصير
  String get shortQuery {
    if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model';
    if (searchKeywords.isNotEmpty) return searchKeywords.take(4).join(' ');
    final clean = displayName;
    return clean.split(' ').take(4).join(' ');
  }

  /// 🇨🇳 الاسم الصيني للمنصات الصينية (Douyin, RedNote, Kuaishou, JD)
  String get bestChineseQuery {
    // 1. إذا كان الاسم الصيني متوفراً ويحتوي على أحرف صينية
    if (chineseName.trim().isNotEmpty && RegExp(r'[\u4e00-\u9fa5]').hasMatch(chineseName)) {
      return chineseName.trim();
    }

    // 2. ترجمة ذكية للمصطلحات التجارية الصينية الشائعة
    final zh = _inferChineseKeywords(displayName.toLowerCase());
    if (zh.isNotEmpty) {
      return model.isNotEmpty ? '$zh $model' : zh;
    }

    // 3. Fallback: استخدام الكلمات المفتاحية النظيفة
    return shortQuery;
  }

  /// قاموس ذكي لتوليد كلمات البحث الصينية الأكثر دقة
  static String _inferChineseKeywords(String lower) {
    if (lower.contains('scalp massager') || lower.contains('head massage') || lower.contains('shampoo brush')) {
      return '电动头皮按摩器';
    }
    if (lower.contains('pet spray') || lower.contains('pet brush') || lower.contains('steamy pet')) {
      return '电动宠物喷雾梳';
    }
    if (lower.contains('lint remover') || lower.contains('fabric shaver') || lower.contains('pilling')) {
      return '毛球修剪器';
    }
    if (lower.contains('straightener') || lower.contains('straightening brush')) {
      return '直发梳';
    }
    if (lower.contains('hair dryer') || lower.contains('blow dryer')) {
      return '高速吹风机';
    }
    if (lower.contains('curler') || lower.contains('curling iron')) {
      return '自动卷发棒';
    }
    if (lower.contains('shaver') || lower.contains('razor') || lower.contains('trimmer')) {
      return '电动剃须刀';
    }
    if (lower.contains('smart watch') || lower.contains('smartwatch')) {
      return '智能手表';
    }
    if (lower.contains('earbuds') || lower.contains('earphones') || lower.contains('headphone')) {
      return '无线蓝牙耳机';
    }
    if (lower.contains('speaker') || lower.contains('soundbar')) {
      return '蓝牙音箱';
    }
    if (lower.contains('blender') || lower.contains('juicer') || lower.contains('smoothie')) {
      return '便携式榨汁杯';
    }
    if (lower.contains('neck massager') || lower.contains('cervical')) {
      return '颈椎按摩仪';
    }
    if (lower.contains('eye massager')) {
      return '眼部按摩仪';
    }
    if (lower.contains('massage gun') || lower.contains('fascia gun')) {
      return '筋膜枪';
    }
    if (lower.contains('massager') || lower.contains('massage')) {
      return '电动按摩器';
    }
    if (lower.contains('water flosser') || lower.contains('oral irrigator')) {
      return '家用冲牙器';
    }
    if (lower.contains('electric toothbrush') || lower.contains('toothbrush')) {
      return '电动牙刷';
    }
    if (lower.contains('projector') || lower.contains('mini projector')) {
      return '家用投影仪';
    }
    if (lower.contains('vacuum') || lower.contains('car cleaner')) {
      return '车载吸尘器';
    }
    if (lower.contains('air purifier')) {
      return '空气净化器';
    }
    if (lower.contains('shoe dryer') || lower.contains('boot dryer')) {
      return '烘鞋器';
    }
    if (lower.contains('label printer') || lower.contains('thermal printer')) {
      return '迷你标签机';
    }
    if (lower.contains('ring light') || lower.contains('fill light')) {
      return '直播补光灯';
    }
    if (lower.contains('phone holder') || lower.contains('car mount')) {
      return '车载手机支架';
    }
    if (lower.contains('tumbler') || lower.contains('thermos') || lower.contains('thermal cup')) {
      return '保温咖啡杯';
    }
    if (lower.contains('coffee grinder')) {
      return '电动磨豆机';
    }
    if (lower.contains('milk frother')) {
      return '电动打奶泡器';
    }
    if (lower.contains('body fat scale') || lower.contains('weight scale')) {
      return '智能体脂秤';
    }
    if (lower.contains('blood pressure') || lower.contains('sphygmomanometer')) {
      return '电子血压计';
    }
    if (lower.contains('spray') || lower.contains('humidifier')) {
      return '加湿喷雾器';
    }
    if (lower.contains('brush') || lower.contains('comb')) {
      return '电动按摩梳';
    }
    return '';
  }

  /// تنظيف النصوص من الكلمات الزائدة
  static String _cleanNoise(String input) {
    return input
        .replaceAll(RegExp(r'\b(unknown brand|brand unknown|model unknown|unknown model|unknown)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(with silicone teeth|lavender purple|handheld|rechargeable)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  String toString() => 'ProductSearchContext(en: $englishName, zh: $chineseName, brand: $brand, model: $model)';
}
