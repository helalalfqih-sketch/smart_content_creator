import 'package:cloud_firestore/cloud_firestore.dart';

/// 🏷️ Brand Identity Model
/// نموذج بيانات الهوية البصرية للمبدع (شعار، تواصل، ألوان)
class BrandIdentity {
  final String? storeName;
  final String? logoUrl;
  final String? phone;
  final String? website;
  final String? instagram;
  final String? tiktok;
  final String? brandColor; // Hex string
  final String? industry; // 🆕 Industry (e.g. Finance, E-commerce, Fashion)
  final DateTime? updatedAt;

  BrandIdentity({
    this.storeName,
    this.logoUrl,
    this.phone,
    this.website,
    this.instagram,
    this.tiktok,
    this.brandColor,
    this.industry,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'logoUrl': logoUrl,
      'phone': phone,
      'website': website,
      'instagram': instagram,
      'tiktok': tiktok,
      'brandColor': brandColor,
      'industry': industry,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory BrandIdentity.fromMap(Map<String, dynamic> map) {
    return BrandIdentity(
      storeName: map['storeName'] as String?,
      logoUrl: map['logoUrl'] as String?,
      phone: map['phone'] as String?,
      website: map['website'] as String?,
      instagram: map['instagram'] as String?,
      tiktok: map['tiktok'] as String?,
      brandColor: map['brandColor'] as String?,
      industry: map['industry'] as String?,
      updatedAt: map['updatedAt'] is Timestamp 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  BrandIdentity copyWith({
    String? storeName,
    String? logoUrl,
    String? phone,
    String? website,
    String? instagram,
    String? tiktok,
    String? brandColor,
    String? industry,
    DateTime? updatedAt,
  }) {
    return BrandIdentity(
      storeName: storeName ?? this.storeName,
      logoUrl: logoUrl ?? this.logoUrl,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      brandColor: brandColor ?? this.brandColor,
      industry: industry ?? this.industry,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
