import 'package:get/get.dart';
import '../controllers/catalog_controller.dart';

/// 🛍️ CatalogProduct Model
/// نموذج بيانات المنتج للكتالوج - متوافق 100% مع متطلبات Meta Commerce Manager
class CatalogProduct {
  final String? id; // SKU - معرف المنتج الفريد
  final String title; // عنوان المنتج
  final String description; // وصف المنتج
  final String availability; // in stock / out of stock
  final String condition; // new / used
  final double price; // السعر
  final String currency; // YER, USD, SAR, etc.
  final String link; // رابط صفحة المنتج
  final String imageLink; // رابط الصورة الرئيسية
  final List<String> additionalImageLinks; // صور إضافية
  final String? videoUrl; // رابط الفيديو
  final String? brand; // العلامة التجارية
  final String? googleProductCategory; // فئة جوجل
  final String? fbProductCategory; // فئة فيسبوك
  final String? categoryId; // معرف الفئة
  final String? categoryName; // اسم الفئة
  final String? metaProductType; // نوع المنتج لـ Meta
  final int quantity; // الكمية المتاحة
  final double? salePrice; // سعر الخصم (اختياري)
  final String? salePriceEffectiveDate; // فترة الخصم
  final String? itemGroupId; // معرف مجموعة المتغيرات
  final String? gender; // female / male / unisex
  final String? color; // اللون
  final String? size; // المقاس
  final String? ageGroup; // الفئة العمرية
  final String? material; // المادة
  final String? pattern; // النمط
  final String? shipping; // الشحن
  final String? shippingWeight; // وزن الشحن
  final String? gtin; // GTIN
  final List<String> productTags; // وسوم المنتج
  final String? style; // الأسلوب
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced; // هل تمت المزامنة مع Meta؟
  final String? creatorUid; // معرف المالك
  final String status; // حالة المراجعة: pending, approved, rejected

  CatalogProduct({
    this.id,
    required this.title,
    required this.description,
    this.availability = 'in stock',
    this.condition = 'new',
    required this.price,
    this.currency = 'YER',
    this.link = '',
    this.imageLink = '',
    this.additionalImageLinks = const [],
    this.videoUrl,
    this.brand,
    this.googleProductCategory,
    this.fbProductCategory,
    this.categoryId,
    this.categoryName,
    this.metaProductType,
    this.quantity = 1,
    this.salePrice,
    this.salePriceEffectiveDate,
    this.itemGroupId,
    this.gender,
    this.color,
    this.size,
    this.ageGroup,
    this.material,
    this.pattern,
    this.shipping,
    this.shippingWeight,
    this.gtin,
    this.productTags = const [],
    this.style,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.creatorUid,
    this.status = 'approved',
  });

  /// ✅ السعر المنسق للمنتج (مثل: 15000 YER)
  String get formattedPrice => '${price.toStringAsFixed(2)} $currency';

  /// ✅ سعر الخصم المنسق
  String? get formattedSalePrice =>
      salePrice != null ? '${salePrice!.toStringAsFixed(2)} $currency' : null;

  /// ✅ اسم الفئة المترجم أو الافتراضي لحساب الإحصائيات
  String get resolvedCategoryName {
    if (categoryName != null && categoryName!.trim().isNotEmpty) {
      return categoryName!.trim();
    }
    
    final gCatLower = googleProductCategory?.trim().toLowerCase() ?? '';
    final fbCatLower = fbProductCategory?.trim().toLowerCase() ?? '';
    
    for (final c in allProductCategories) {
      final targetG = c.googleCategory.trim().toLowerCase();
      final targetFb = c.fbCategory.trim().toLowerCase();
      
      if (c.id == categoryId) return c.name;
      
      if (targetG.isNotEmpty && (gCatLower.startsWith(targetG) || gCatLower == targetG)) {
        return c.name;
      }
      if (targetFb.isNotEmpty && (fbCatLower.startsWith(targetFb) || fbCatLower == targetFb)) {
        return c.name;
      }
    }
    
    // محاولات مطابقة الكلمات المفتاحية
    if (gCatLower.contains('kitchen')) {
      return '🍳 المطبخ';
    }
    if (gCatLower.contains('storage') || gCatLower.contains('organization')) {
      return '🧺 التنظيم والتخزين';
    }
    if (gCatLower.contains('beauty') || gCatLower.contains('cosmetic')) {
      return '🧴 الجمال والعناية';
    }
    if (gCatLower.contains('massage') || gCatLower.contains('relax')) {
      return '💆 الصحة والمساج';
    }
    if (gCatLower.contains('hardware') || gCatLower.contains('tool') || gCatLower.contains('adhesive')) {
      return '🛠️ العدد والأدوات';
    }
    if (gCatLower.contains('vehicle') || gCatLower.contains('car') || gCatLower.contains('parts') || gCatLower.contains('automotive')) {
      return '🚗 السيارات';
    }
    if (gCatLower.contains('sport') || gCatLower.contains('fitness') || gCatLower.contains('exercise')) {
      return '🏃 الرياضة واللياقة';
    }
    if (gCatLower.contains('outdoor') || gCatLower.contains('camp') || gCatLower.contains('hike')) {
      return '🏕️ الرحلات والخارجية';
    }
    if (gCatLower.contains('toy') || gCatLower.contains('game') || gCatLower.contains('kid') || gCatLower.contains('baby')) {
      return '👶 الأطفال والألعاب';
    }
    if (gCatLower.contains('electronic') || gCatLower.contains('camera') || gCatLower.contains('phone')) {
      return '🔌 الإلكترونيات';
    }
    if (gCatLower.contains('decor') || gCatLower.contains('furniture')) {
      return '🏠 المنزل والديكور';
    }
    if (gCatLower.contains('light') || gCatLower.contains('energy') || gCatLower.contains('power') || gCatLower.contains('solar')) {
      return '💡 الإضاءة والطاقة';
    }
    if (gCatLower.contains('pet') || gCatLower.contains('dog') || gCatLower.contains('cat')) {
      return '🐾 الحيوانات الأليفة';
    }
    if (gCatLower.contains('appliances') || gCatLower.contains('home') || gCatLower.contains('garden')) {
      return '🏠 المنزل والديكور';
    }
    
    return '🛍️ متنوعات';
  }

  // ---------------------------------------------------------------------------
  // 🔁 تحويل إلى وصف Map لقاعدة البيانات
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'availability': availability,
      'condition': condition,
      'price': price,
      'currency': currency,
      'link': link,
      'image_link': imageLink,
      'additional_image_links': additionalImageLinks.join(','),
      'video_url': videoUrl,
      'brand': brand,
      'google_product_category': googleProductCategory,
      'fb_product_category': fbProductCategory,
      'category_id': categoryId,
      'category_name': categoryName,
      'meta_product_type': metaProductType,
      'quantity': quantity,
      'sale_price': salePrice,
      'sale_price_effective_date': salePriceEffectiveDate,
      'item_group_id': itemGroupId,
      'gender': gender,
      'color': color,
      'size': size,
      'age_group': ageGroup,
      'material': material,
      'pattern': pattern,
      'shipping': shipping,
      'shipping_weight': shippingWeight,
      'gtin': gtin,
      'product_tags': productTags.join(','),
      'style': style,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'creator_uid': creatorUid,
      'status': status,
    };
  }

  // ---------------------------------------------------------------------------
  // 🏭 إنشاء من Map (قاعدة البيانات)
  // ---------------------------------------------------------------------------
  factory CatalogProduct.fromMap(Map<String, dynamic> map) {
    return CatalogProduct(
      id: map['id']?.toString(),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      availability: map['availability'] as String? ?? 'in stock',
      condition: map['condition'] as String? ?? 'new',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'YER',
      link: map['link'] as String? ?? '',
      imageLink: map['image_link'] as String? ?? '',
      additionalImageLinks: (map['additional_image_links'] as String? ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      videoUrl: map['video_url'] as String?,
      brand: map['brand'] as String?,
      googleProductCategory: map['google_product_category'] as String?,
      fbProductCategory: map['fb_product_category'] as String?,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      metaProductType: map['meta_product_type'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      salePriceEffectiveDate: map['sale_price_effective_date'] as String?,
      itemGroupId: map['item_group_id'] as String?,
      gender: map['gender'] as String?,
      color: map['color'] as String?,
      size: map['size'] as String?,
      ageGroup: map['age_group'] as String?,
      material: map['material'] as String?,
      pattern: map['pattern'] as String?,
      shipping: map['shipping'] as String?,
      shippingWeight: map['shipping_weight'] as String?,
      gtin: map['gtin'] as String?,
      productTags: (map['product_tags'] as String? ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      style: map['style'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      creatorUid: map['creator_uid'] as String?,
      status: map['status'] as String? ?? 'approved',
    );
  }

  // ---------------------------------------------------------------------------
  // 📑 تحويل صف Excel إلى نموذج
  // ---------------------------------------------------------------------------
  factory CatalogProduct.fromExcelRow(List<dynamic> row, int rowIndex) {
    String safe(int i) {
      if (i >= row.length || row[i] == null) return '';
      final val = row[i];
      return val.toString().trim();
    }

    double? safePrice(int i) {
      final s = safe(i);
      final clean = s.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(clean);
    }

    String priceRaw = safe(5);
    String detectedCurrency = 'YER';
    if (priceRaw.toUpperCase().contains('YER')) {
      detectedCurrency = 'YER';
    } else if (priceRaw.toUpperCase().contains('USD')) {
      detectedCurrency = 'USD';
    } else if (priceRaw.toUpperCase().contains('SAR')) {
      detectedCurrency = 'SAR';
    }

    // Check if column 8 contains additional image links (comma-separated or url)
    List<String> additionalImages = [];
    String? brandVal;
    if (safe(8).startsWith('http') || safe(8).contains(',')) {
      additionalImages = safe(8)
          .split(',')
          .map((u) => u.trim())
          .where((u) => u.startsWith('http'))
          .toList();
    } else if (safe(8).isNotEmpty) {
      brandVal = safe(8);
    }

    return CatalogProduct(
      id: safe(0).isNotEmpty ? safe(0) : 'product_$rowIndex',
      title: safe(1),
      description: safe(2),
      availability: safe(3).isNotEmpty ? safe(3) : 'in stock',
      condition: safe(4).isNotEmpty ? safe(4) : 'new',
      price: safePrice(5) ?? 0.0,
      currency: detectedCurrency,
      link: safe(6),
      imageLink: safe(7),
      additionalImageLinks: additionalImages,
      brand: brandVal,
      googleProductCategory: safe(9).isNotEmpty ? safe(9) : null,
      fbProductCategory: safe(10).isNotEmpty ? safe(10) : null,
      quantity: int.tryParse(safe(11)) ?? 1,
      salePrice: safePrice(12),
      salePriceEffectiveDate: safe(13).isNotEmpty ? safe(13) : null,
      itemGroupId: safe(14).isNotEmpty ? safe(14) : null,
      gender: safe(15).isNotEmpty ? safe(15) : null,
      color: safe(16).isNotEmpty ? safe(16) : null,
      size: safe(17).isNotEmpty ? safe(17) : null,
      ageGroup: safe(18).isNotEmpty ? safe(18) : null,
      material: safe(19).isNotEmpty ? safe(19) : null,
      pattern: safe(20).isNotEmpty ? safe(20) : null,
      shipping: safe(21).isNotEmpty ? safe(21) : null,
      shippingWeight: safe(22).isNotEmpty ? safe(22) : null,
      gtin: safe(27).isNotEmpty ? safe(27) : null,
      productTags: [safe(28), safe(29)].where((e) => e.isNotEmpty).toList(),
      style: safe(30).isNotEmpty ? safe(30) : null,
      creatorUid: null,
      status: 'approved',
    );
  }

  // ---------------------------------------------------------------------------
  // 📑 تحويل صف CSV إلى نموذج منتج
  // ---------------------------------------------------------------------------
  factory CatalogProduct.fromCsvFields(List<String> fields) {
    String val(int idx) => idx < fields.length ? fields[idx].trim() : '';

    double parsePriceVal(String pStr) {
      final clean = pStr.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(clean) ?? 0.0;
    }

    double? parseSalePriceVal(String pStr) {
      if (pStr.isEmpty) return null;
      final clean = pStr.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(clean);
    }

    final priceVal = parsePriceVal(val(5));
    final salePriceVal = parseSalePriceVal(val(16));

    final addImgs = <String>[];
    for (int i = 8; i <= 11; i++) {
      final img = val(i);
      if (img.isNotEmpty) addImgs.add(img);
    }

    final tags = <String>[];
    if (val(32).isNotEmpty) tags.add(val(32));
    if (val(33).isNotEmpty) tags.add(val(33));

    return CatalogProduct(
      id: val(0),
      title: val(1),
      description: val(2),
      availability: val(3).isNotEmpty ? val(3) : 'in stock',
      condition: val(4).isNotEmpty ? val(4) : 'new',
      price: priceVal,
      currency: val(5).contains(' ') ? val(5).split(' ').last : 'YER',
      link: val(6),
      imageLink: val(7) == 'https://placehold.co/600x600.png?text=No+Image' ? '' : val(7),
      additionalImageLinks: addImgs,
      brand: val(12).isNotEmpty ? val(12) : null,
      googleProductCategory: val(13).isNotEmpty ? val(13) : null,
      fbProductCategory: val(14).isNotEmpty ? val(14) : null,
      quantity: int.tryParse(val(15)) ?? 1,
      salePrice: salePriceVal,
      salePriceEffectiveDate: val(17).isNotEmpty ? val(17) : null,
      itemGroupId: val(18).isNotEmpty ? val(18) : null,
      gender: val(19).isNotEmpty ? val(19) : null,
      color: val(20).isNotEmpty ? val(20) : null,
      size: val(21).isNotEmpty ? val(21) : null,
      ageGroup: val(22).isNotEmpty ? val(22) : null,
      material: val(23).isNotEmpty ? val(23) : null,
      pattern: val(24).isNotEmpty ? val(24) : null,
      shipping: val(25).isNotEmpty ? val(25) : null,
      shippingWeight: val(26).isNotEmpty ? val(26) : null,
      videoUrl: val(29).isNotEmpty ? val(29) : null,
      gtin: val(31).isNotEmpty ? val(31) : null,
      productTags: tags,
      style: val(34).isNotEmpty ? val(34) : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isSynced: true,
      creatorUid: null,
      status: 'approved',
    );
  }


  String toCsvRow({String? defaultLink}) {
    String escCsv(String? v) {
      if (v == null || v.isEmpty) return '';
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final itemLink = link.trim().isNotEmpty 
        ? link.trim() 
        : (defaultLink ?? 'https://example.com/product/${id ?? ""}');

    // الصور الإضافية (حتى 4 صور) - Meta تقبل additional_image_link[0] إلى [3]
    final addImgs = List.generate(
      4,
      (i) => escCsv(i < additionalImageLinks.length ? additionalImageLinks[i] : null),
    );

    final fields = [
      escCsv(id),
      escCsv(title),
      escCsv(description),
      escCsv(availability),
      escCsv(condition),
      escCsv(formattedPrice),
      escCsv(itemLink),
      escCsv(imageLink.isNotEmpty ? imageLink : 'https://placehold.co/600x600.png?text=No+Image'),
      addImgs[0], // additional_image_link[0]
      addImgs[1], // additional_image_link[1]
      addImgs[2], // additional_image_link[2]
      addImgs[3], // additional_image_link[3]
      escCsv(brand),
      escCsv(googleProductCategory),
      escCsv(fbProductCategory),
      quantity.toString(),
      escCsv(formattedSalePrice),
      escCsv(salePriceEffectiveDate),
      escCsv(itemGroupId),
      escCsv(gender),
      escCsv(color),
      escCsv(size),
      escCsv(ageGroup),
      escCsv(material),
      escCsv(pattern),
      escCsv(shipping),
      escCsv(shippingWeight),
      '', // offer_disclaimer
      '', // offer_disclaimer_url
      escCsv(videoUrl),
      '', // video tag
      escCsv(gtin),
      escCsv(productTags.isNotEmpty ? productTags[0] : null),
      escCsv(productTags.length > 1 ? productTags[1] : null),
      escCsv(style),
      escCsv(resolvedCategoryName),
    ];
    return fields.join(',');
  }

  // ---------------------------------------------------------------------------
  // 📋 هيدر الـ CSV المتوافق مع Meta
  // ---------------------------------------------------------------------------
  static const String csvHeader =
      'id,title,description,availability,condition,price,link,image_link,additional_image_link[0],additional_image_link[1],additional_image_link[2],additional_image_link[3],brand,google_product_category,fb_product_category,quantity_to_sell_on_facebook,sale_price,sale_price_effective_date,item_group_id,gender,color,size,age_group,material,pattern,shipping,shipping_weight,offer_disclaimer,offer_disclaimer_url,video[0].url,video[0].tag[0],gtin,product_tags[0],product_tags[1],style[0],product_type';

  // ---------------------------------------------------------------------------
  // 📝 نسخة معدلة مع تحديثات
  // ---------------------------------------------------------------------------
  CatalogProduct copyWith({
    String? id,
    String? title,
    String? description,
    String? availability,
    String? condition,
    double? price,
    String? currency,
    String? link,
    String? imageLink,
    List<String>? additionalImageLinks,
    String? videoUrl,
    String? brand,
    String? googleProductCategory,
    String? fbProductCategory,
    String? categoryId,
    String? categoryName,
    String? metaProductType,
    int? quantity,
    double? salePrice,
    String? salePriceEffectiveDate,
    String? itemGroupId,
    String? gender,
    String? color,
    String? size,
    String? ageGroup,
    String? material,
    String? pattern,
    String? shipping,
    String? shippingWeight,
    String? gtin,
    List<String>? productTags,
    String? style,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? creatorUid,
    String? status,
  }) {
    return CatalogProduct(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      availability: availability ?? this.availability,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      link: link ?? this.link,
      imageLink: imageLink ?? this.imageLink,
      additionalImageLinks: additionalImageLinks ?? this.additionalImageLinks,
      videoUrl: videoUrl ?? this.videoUrl,
      brand: brand ?? this.brand,
      googleProductCategory: googleProductCategory ?? this.googleProductCategory,
      fbProductCategory: fbProductCategory ?? this.fbProductCategory,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      metaProductType: metaProductType ?? this.metaProductType,
      quantity: quantity ?? this.quantity,
      salePrice: salePrice ?? this.salePrice,
      salePriceEffectiveDate:
          salePriceEffectiveDate ?? this.salePriceEffectiveDate,
      itemGroupId: itemGroupId ?? this.itemGroupId,
      gender: gender ?? this.gender,
      color: color ?? this.color,
      size: size ?? this.size,
      ageGroup: ageGroup ?? this.ageGroup,
      material: material ?? this.material,
      pattern: pattern ?? this.pattern,
      shipping: shipping ?? this.shipping,
      shippingWeight: shippingWeight ?? this.shippingWeight,
      gtin: gtin ?? this.gtin,
      productTags: productTags ?? this.productTags,
      style: style ?? this.style,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      creatorUid: creatorUid ?? this.creatorUid,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'CatalogProduct(id: $id, title: $title, price: $formattedPrice)';
}

class ProductCategoryInfo {
  final String id;
  final String name;
  final String googleCategory;
  final String fbCategory;

  const ProductCategoryInfo({
    required this.id,
    required this.name,
    required this.googleCategory,
    required this.fbCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'googleCategory': googleCategory,
      'fbCategory': fbCategory,
    };
  }

  factory ProductCategoryInfo.fromMap(Map<String, dynamic> map) {
    return ProductCategoryInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      googleCategory: map['googleCategory'] ?? '',
      fbCategory: map['fbCategory'] ?? '',
    );
  }
}

/// ✅ جلب كافة الفئات (الافتراضية والمخصصة بواسطة المستخدم)
List<ProductCategoryInfo> get allProductCategories {
  if (Get.isRegistered<CatalogController>()) {
    return Get.find<CatalogController>().allCategories;
  }
  return predefinedCategories;
}

const List<ProductCategoryInfo> predefinedCategories = [
  ProductCategoryInfo(
    id: 'kitchen',
    name: '🍳 المطبخ',
    googleCategory: 'Home & Garden > Kitchen & Dining',
    fbCategory: 'Home & Garden > Kitchen & Dining',
  ),
  ProductCategoryInfo(
    id: 'storage_organization',
    name: '🧺 التنظيم والتخزين',
    googleCategory: 'Home & Garden > Household Supplies > Storage & Organization',
    fbCategory: 'Home & Garden > Household Supplies > Storage & Organization',
  ),
  ProductCategoryInfo(
    id: 'beauty_care',
    name: '🧴 الجمال والعناية',
    googleCategory: 'Health & Beauty > Personal Care',
    fbCategory: 'Health & Beauty > Personal Care',
  ),
  ProductCategoryInfo(
    id: 'health_massage',
    name: '💆 الصحة والمساج',
    googleCategory: 'Health & Beauty > Health Care',
    fbCategory: 'Health & Beauty > Health Care',
  ),
  ProductCategoryInfo(
    id: 'tools_hardware',
    name: '🛠️ العدد والأدوات',
    googleCategory: 'Hardware',
    fbCategory: 'Hardware',
  ),
  ProductCategoryInfo(
    id: 'automotive',
    name: '🚗 السيارات',
    googleCategory: 'Vehicles & Parts',
    fbCategory: 'Vehicles & Parts',
  ),
  ProductCategoryInfo(
    id: 'sports_fitness',
    name: '🏃 الرياضة واللياقة',
    googleCategory: 'Sporting Goods > Athletics > Exercise & Fitness',
    fbCategory: 'Sporting Goods > Athletics > Exercise & Fitness',
  ),
  ProductCategoryInfo(
    id: 'camping_outdoor',
    name: '🏕️ الرحلات والخارجية',
    googleCategory: 'Sporting Goods > Outdoor Recreation > Camping & Hiking',
    fbCategory: 'Sporting Goods > Outdoor Recreation > Camping & Hiking',
  ),
  ProductCategoryInfo(
    id: 'kids_toys',
    name: '👶 الأطفال والألعاب',
    googleCategory: 'Toys & Games',
    fbCategory: 'Toys & Games',
  ),
  ProductCategoryInfo(
    id: 'electronics',
    name: '🔌 الإلكترونيات',
    googleCategory: 'Electronics',
    fbCategory: 'Electronics',
  ),
  ProductCategoryInfo(
    id: 'home_decor',
    name: '🏠 المنزل والديكور',
    googleCategory: 'Home & Garden > Decor',
    fbCategory: 'Home & Garden > Decor',
  ),
  ProductCategoryInfo(
    id: 'lighting_energy',
    name: '💡 الإضاءة والطاقة',
    googleCategory: 'Home & Garden > Lighting',
    fbCategory: 'Home & Garden > Lighting',
  ),
  ProductCategoryInfo(
    id: 'pets',
    name: '🐾 الحيوانات الأليفة',
    googleCategory: 'Pet Supplies',
    fbCategory: 'Pet Supplies',
  ),
  ProductCategoryInfo(
    id: 'general_miscellaneous',
    name: '🛍️ متنوعات',
    googleCategory: 'Home & Garden',
    fbCategory: 'Home & Garden',
  ),
  ProductCategoryInfo(
    id: 'other',
    name: 'أخرى',
    googleCategory: 'Home & Garden',
    fbCategory: 'Home & Garden',
  ),
];
