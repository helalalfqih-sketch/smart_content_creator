/// 🧠 Product Memory Model
/// نموذج لحفظ آخر منتج تم تحليله لكل مستخدم
class ProductMemoryModel {
  final int? id;
  final String userId;
  final String productName;
  final String? productNameEn;
  final String? brandName;
  final String? brandNameEn;
  final String? category;
  final String? model;
  final String searchQuery;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductMemoryModel({
    this.id,
    required this.userId,
    required this.productName,
    this.productNameEn,
    this.brandName,
    this.brandNameEn,
    this.category,
    this.model,
    required this.searchQuery,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// تحويل إلى Map لقاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'product_name': productName,
      'product_name_en': productNameEn,
      'brand_name': brandName,
      'brand_name_en': brandNameEn,
      'category': category,
      'model': model,
      'search_query': searchQuery,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// إنشاء من Map (قاعدة البيانات)
  factory ProductMemoryModel.fromMap(Map<String, dynamic> map) {
    return ProductMemoryModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      productName: map['product_name'] as String,
      productNameEn: map['product_name_en'] as String?,
      brandName: map['brand_name'] as String?,
      brandNameEn: map['brand_name_en'] as String?,
      category: map['category'] as String?,
      model: map['model'] as String?,
      searchQuery: map['search_query'] as String,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// نسخ مع تحديثات
  ProductMemoryModel copyWith({
    int? id,
    String? userId,
    String? productName,
    String? productNameEn,
    String? brandName,
    String? brandNameEn,
    String? category,
    String? model,
    String? searchQuery,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductMemoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      productNameEn: productNameEn ?? this.productNameEn,
      brandName: brandName ?? this.brandName,
      brandNameEn: brandNameEn ?? this.brandNameEn,
      category: category ?? this.category,
      model: model ?? this.model,
      searchQuery: searchQuery ?? this.searchQuery,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductMemoryModel(id: $id, userId: $userId, productName: $productName, brandName: $brandName, category: $category)';
  }
}
