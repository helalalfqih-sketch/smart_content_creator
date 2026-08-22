/// 🗂️ CatalogCategory Model
/// نموذج فئات الكتالوج المزامنة مع Back4App
class CatalogCategory {
  final String categoryId;
  final String name;
  final String nameAr;
  final String slug;
  final String googleCategory;
  final String fbCategory;
  final String imageUrl;
  final int sortOrder;
  final bool active;
  final String scope;
  final String? creatorUid;
  final Map<String, dynamic>? metadata;

  CatalogCategory({
    required this.categoryId,
    required this.name,
    this.nameAr = '',
    this.slug = '',
    this.googleCategory = '',
    this.fbCategory = '',
    this.imageUrl = '',
    this.sortOrder = 0,
    this.active = true,
    this.scope = 'global',
    this.creatorUid,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'name': name,
      'name_ar': nameAr,
      'slug': slug,
      'google_category': googleCategory,
      'fb_category': fbCategory,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'active': active ? 1 : 0,
      'scope': scope,
      'creator_uid': creatorUid,
    };
  }

  factory CatalogCategory.fromMap(Map<String, dynamic> map) {
    return CatalogCategory(
      categoryId: (map['category_id'] ?? map['categoryId'])?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      nameAr: (map['name_ar'] ?? map['nameAr'])?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      googleCategory: (map['google_category'] ?? map['googleCategory'])?.toString() ?? '',
      fbCategory: (map['fb_category'] ?? map['fbCategory'])?.toString() ?? '',
      imageUrl: (map['image_url'] ?? map['imageUrl'])?.toString() ?? '',
      sortOrder: (map['sort_order'] ?? map['sortOrder'] as num?)?.toInt() ?? 0,
      active: map['active'] == 1 || map['active'] == true,
      scope: map['scope']?.toString() ?? 'global',
      creatorUid: (map['creator_uid'] ?? map['creatorUid'])?.toString(),
    );
  }
}
