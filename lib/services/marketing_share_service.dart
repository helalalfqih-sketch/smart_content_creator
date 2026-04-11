import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../ai/core/agent_models.dart';
import '../models/brand_info.dart';

class MarketingShareService {
  /// 🧠 Generate a smart marketing description for a product
  String generateProductDescription(ImageItem item, {BrandInfo? brand}) {
    final List<String> lines = [];

    // 1. Headline
    lines.add("✨ ${item.title}");
    lines.add("اكتشف هذا المنتج الرائع المتوفر الآن بمواصفات تخبلك! 😍");
    lines.add("");

    // 2. Features (Mock features if not available in metadata)
    lines.add("[المميزات]");
    final metadata = item.metadata ?? {};
    final List<String> features = (metadata['features'] as List?)?.cast<String>() ?? 
        ["جودة عالية", "تصميم عصري", "أفضل سعر في السوق"];
    
    for (var feature in features) {
      lines.add("🔹 $feature");
    }
    lines.add("");

    // 3. Optional Price
    final price = metadata['price'] ?? "";
    if (price.toString().isNotEmpty) {
      lines.add("💰 السعر: $price");
      lines.add("");
    }

    // 4. Brand Section if enabled and not empty
    if (brand != null && !brand.isEmpty) {
      lines.add("━━━━━━━━━━━━━━━");
      lines.add("🏪 المتجر: ${brand.name}");
      if (brand.industry != null && brand.industry!.isNotEmpty) {
        lines.add("📦 النشاط: ${brand.industry}");
      }
      if (brand.phone != null && brand.phone!.isNotEmpty) {
        lines.add("📱 واتساب: ${brand.waLink}");
      }
      if (brand.website != null && brand.website!.isNotEmpty) {
        lines.add("🌐 الموقع: ${brand.website}");
      }
      lines.add("━━━━━━━━━━━━━━━");
      lines.add("");
    }

    // 5. CTA
    lines.add("اطلبه الآن ولا تضيع الفرصة! ⚡");
    lines.add("");

    // 6. Hashtags
    lines.add(generateHashtags(brand?.industry ?? "تسوق"));

    // Cleanup empty lines and return
    return lines.where((l) => l.isNotEmpty || l == "").join("\n").trim();
  }

  /// 📈 Auto-generate industry-relevant hashtags
  String generateHashtags(String industry) {
    final lower = industry.toLowerCase();
    if (lower.contains("fashion") || lower.contains("أزياء") || lower.contains("ملابس")) {
      return "#موضة #ستايل #أزياء #تسوق #فاشن";
    } else if (lower.contains("electronic") || lower.contains("إلكترونيات") || lower.contains("تقنية")) {
      return "#الكترونيات #تقنية #ابتكار #أجهزة #تكنولوجيا";
    } else if (lower.contains("fitness") || lower.contains("رياضة") || lower.contains("صحة")) {
      return "#رياضة #لياقة #صحة #تمرين #نشاط";
    } else if (lower.contains("food") || lower.contains("مطعم") || lower.contains("أكل")) {
      return "#أكل #مطاعم #وصفات #لذيذ #طبخ";
    } else if (lower.contains("beauty") || lower.contains("تجميل") || lower.contains("مكياج")) {
      return "#تجميل #عناية #مكياج #بشرة #نضارة";
    }
    return "#تسوق #منتجات #أونلاين #عروض #سمارت";
  }

  /// 🚀 Core Share Logic: Download files and trigger Native Share Sheet
  Future<void> shareImages({
    required List<ImageItem> items,
    required String text,
    String subject = "مشاركة منتج من Smart Content Creator",
  }) async {
    if (items.isEmpty) return;

    try {
      final List<XFile> xFiles = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final imageUrl = item.originalUrl ?? item.link;
        if (imageUrl.isEmpty) continue;

        debugPrint("📥 Downloading image $i: $imageUrl");
        final response = await http.get(Uri.parse(imageUrl));
        
        if (response.statusCode == 200) {
          final fileName = 'share_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          xFiles.add(XFile(filePath));
        }
      }

      if (xFiles.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: xFiles,
            text: text,
            subject: subject,
          ),
        );
      } else {
        throw Exception("لم نتمكن من تحميل أي صورة للمشاركة");
      }
    } catch (e) {
      debugPrint("❌ Share Service Error: $e");
      rethrow;
    }
  }
}
