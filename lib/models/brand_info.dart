/// 🏷️ Brand Info Model for Marketing Share System
class BrandInfo {
  final String? name;
  final String? industry;
  final String? phone;
  final String? website;

  const BrandInfo({
    this.name,
    this.industry,
    this.phone,
    this.website,
  });

  bool get isEmpty => (name == null || name!.isEmpty);

  String get waLink => phone != null && phone!.isNotEmpty 
      ? "https://wa.me/${phone!.replaceAll(RegExp(r'[^0-9]'), '')}" 
      : "";

  factory BrandInfo.empty() => const BrandInfo();
}
