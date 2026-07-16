import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:get/get.dart';
import '../core/agent_models.dart';
import '../../ai/ai_orchestrator.dart';
import '../../widgets/scanning_overlay_painter.dart';
import '../../controllers/marketing_share_controller.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/theme/ui_kit/smart_glass_card.dart';
import '../../core/theme/ui_kit/smart_soft_icon.dart';
import '../../core/theme/ui_kit/smart_bouncy_wrapper.dart';
import '../../theme/app_theme.dart';

/// 🖼️ ImageGalleryWidget - A premium grid display for visual inspiration.
/// Used to show similar product images or style moodboards.
class ImageGalleryWidget extends StatelessWidget {
  final ImageGalleryData data;
  final List<SuggestedAction>? actions;

  const ImageGalleryWidget({
    super.key,
    required this.data,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final shareController = Get.put(MarketingShareController());
    final isExpanded = false.obs;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SmartGlassCard(
        borderRadius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title Section
            _buildHeader(context, shareController, isExpanded),

            // 2. Grid Section (Collapsible)
            Obx(() => AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded.value ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: data.images.take(10).length, // Show top 10
                      itemBuilder: (context, index) {
                        return _buildImageCard(context, data.images[index], index);
                      },
                    ),
                  ),
                  // 3. Actions Section
                  if (actions != null && actions!.isNotEmpty) _buildActions(),
                ],
              ),
            )),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MarketingShareController shareController, RxBool isExpanded) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SmartSoftIcon(icon: Icons.auto_awesome_outlined, size: 16, padding: 8),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.45),
                child: Text(
                  data.title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          // 🏷️ Brand Toggle & Expand Toggle
          Obx(() => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "البراند",
                style: GoogleFonts.cairo(color: Colors.white54, fontSize: 10),
              ),
              Transform.scale(
                scale: 0.6,
                child: Switch(
                  value: shareController.includeBrand.value,
                  onChanged: shareController.toggleIncludeBrand,
                  activeThumbColor: AppTheme.primary,
                  activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              // 👁️ Show/Hide Toggle Button
              GestureDetector(
                onTap: () => isExpanded.toggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded.value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: isExpanded.value ? AppTheme.primary : Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExpanded.value ? "إخفاء" : "عرض",
                        style: GoogleFonts.cairo(
                            color: isExpanded.value ? AppTheme.primary : Colors.white, 
                            fontSize: 11, 
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, ImageItem item, int index) {
    return SmartBouncyWrapper(
      onTap: () => _showPreview(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.thumbnail,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white.withValues(alpha: 0.03),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Source Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                item.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8,
        children: actions!.map((action) => _buildActionButton(action)).toList(),
      ),
    );
  }

  Widget _buildActionButton(SuggestedAction action) {
    return SmartBouncyWrapper(
      onTap: () {
        final orchestrator = Get.find<AIOrchestrator>();
        orchestrator.processUserInput(
          text: "${action.label}: ${data.query}",
        );
      },
      child: Chip(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
        label: Text(
            action.label, 
            style: GoogleFonts.cairo(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  void _showPreview(BuildContext context, int initialIndex) {
    final PageController pageController = PageController(initialPage: initialIndex);
    
    showDialog(
      context: context,
      builder: (context) {
        bool isScanning = false;
        bool isPreparingSmartShare = false; // 🆕 Track AI preparation
        
        return StatefulBuilder(
          builder: (context, setDialogState) {

            final index = pageController.hasClients ? (pageController.page?.round() ?? initialIndex) : initialIndex;
            final totalImages = data.images.length;
            final safeIndex = (index >= 0 && index < totalImages) ? index : (totalImages > 0 ? 0 : -1);
            
            final currentItem = safeIndex != -1 ? data.images[safeIndex] : null;
            final currentIndex = safeIndex;

            if (currentItem == null) return const SizedBox.shrink();

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎞️ Carousel Container
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: AnimatedBuilder(
                    animation: pageController,
                    builder: (context, child) {
                      return PageView.builder(
                        controller: pageController,
                        itemCount: totalImages,
                        onPageChanged: (index) {
                          setDialogState(() {
                            isScanning = false; // Reset lens on swipe
                          });
                        },
                        itemBuilder: (context, index) {
                          double value = 0.0;
                          if (pageController.position.haveDimensions) {
                            value = index.toDouble() - (pageController.page ?? 0);
                          } else {
                            value = index.toDouble() - initialIndex.toDouble();
                          }

                          // 🌀 3D Transform Logic
                          final double scale = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                          final double rotationY = (value * 0.2).clamp(-0.4, 0.4);

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // Perspective
                              ..rotateY(rotationY)
                              ..scaleByVector3(vmath.Vector3(scale, scale, 1.0)),
                            alignment: Alignment.center,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: CachedNetworkImage(
                                        imageUrl: data.images[index].originalUrl ?? data.images[index].link,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.white24),
                                      ),
                                    ),
                                    // 🔍 Lens Scanning Overlay (Triggered on demand)
                                    if (isScanning && value.abs() < 0.1) ...[
                                      const ScanningOverlay(),
                                      Positioned(
                                        top: 15,
                                        right: 15,
                                        child: GestureDetector(
                                          onTap: () => setDialogState(() => isScanning = false),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // 🔘 Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    totalImages > 8 ? 8 : totalImages, // Limit indicators to 8
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: currentIndex == index ? 10 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: currentIndex == index ? AppTheme.primary : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 🏷️ Source Info (Animated switch)
                Text(
                  currentItem.source,
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 12),

                // 🧪 Quick Actions Row (Share, Save, Lens, Analyze)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPreviewActionButton(
                      icon: isPreparingSmartShare ? Icons.auto_awesome : Icons.share_rounded,
                      label: isPreparingSmartShare ? "جاري..." : "مشاركة",
                      color: AppTheme.primary,
                      onTap: () async {
                        if (isPreparingSmartShare) return;
                        setDialogState(() => isPreparingSmartShare = true);
                        try {
                          await _shareImage(context, currentItem);
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isPreparingSmartShare = false);
                          }
                        }
                      },
                      onLongPress: () => showShareOptions(context, currentItem),
                    ),
                    const SizedBox(width: 12),
                    _buildPreviewActionButton(
                      icon: Icons.psychology_rounded,
                      label: "تحليل",
                      color: Colors.cyanAccent,
                      onTap: () => _analyzeInChat(context, currentItem),
                    ),
                    const SizedBox(width: 12),
                    _buildPreviewActionButton(
                      icon: Icons.download_rounded,
                      label: "حفظ",
                      color: Colors.white,
                      onTap: () => _saveImage(context, currentItem),
                    ),
                    const SizedBox(width: 12),
                    _buildPreviewActionButton(
                      icon: Icons.center_focus_strong_rounded,
                      label: "عدسة",
                      color: AppTheme.accent,
                      onTap: () async {
                        setDialogState(() => isScanning = true);
                        await Future.delayed(const Duration(seconds: 2));
                        if (context.mounted && isScanning) {
                          setDialogState(() => isScanning = false);
                          _lensSearch(context, currentItem);
                        }
                      },
                    ),
                  ],
                ),


                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _launchUrl(currentItem.link),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text("فتح المصدر", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("إغلاق", style: GoogleFonts.cairo()),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildPreviewActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SmartBouncyWrapper(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.cairo(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }


  Future<void> _shareImage(BuildContext context, ImageItem item) async {
    final shareController = Get.find<MarketingShareController>();
    
    try {
      // 1️⃣ جلب وصف تسويقي ذكي تلقائي بناءً على المنتج
      // Find orchestrator OR use unified AI directly
      String? smartDescription;
      try {
         final orchestrator = Get.find<AIOrchestrator>();
         smartDescription = await orchestrator.generateMarketingDescription(
           query: item.title, // Use title for ad context
         );
      } catch (e) {
        debugPrint("⚠️ AIOrchestrator not found or failed, falling back to local: $e");
      }

      // 2️⃣ إرسال الصورة + الوصف للتشارك
      if (!context.mounted) return;
      
      await shareController.performShare(
        context: context, 
        items: [item],
        overrideDescription: (smartDescription != null && smartDescription.isNotEmpty) 
            ? smartDescription 
            : null,
      );
    } catch (e) {
      debugPrint("❌ Share Error: $e");
    }
  }



  /// 🍱 Show Share Options Bottom Sheet
  void showShareOptions(BuildContext context, ImageItem item) {
    final shareController = Get.find<MarketingShareController>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 32.0,
        opacity: 0.1,

        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "خيارات المشاركة الذكية 🚀",
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "اختر كيف تريد مشاركة هذا المنتج",
                style: GoogleFonts.cairo(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildShareOptionItem(
                title: "مشاركة تسويقية كاملة",
                subtitle: "صورة + وصف جذاب + معلومات براندك",
                icon: Icons.auto_awesome,
                color: AppTheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  shareController.performShare(context: context, items: [item], overrideIncludeBrand: true);
                },
              ),
              const SizedBox(height: 12),
              _buildShareOptionItem(
                title: "مشاركة سريعة (بدون براند)",
                subtitle: "صورة + وصف المنتج فقط",
                icon: Icons.flash_on_rounded,
                color: Colors.white70,
                onTap: () {
                  Navigator.pop(context);
                  shareController.performShare(context: context, items: [item], overrideIncludeBrand: false);
                },
              ),
              const SizedBox(height: 12),
              if (data.images.length > 1) 
                _buildShareOptionItem(
                  title: "مشاركة جميع الصور (${data.images.length})",
                  subtitle: "مشاركة المجموعة كاملة بتنسيق تسويقي",
                  icon: Icons.collections_rounded,
                  color: AppTheme.accent,
                  onTap: () {
                    Navigator.pop(context);
                    shareController.performShare(context: context, items: data.images, overrideIncludeBrand: true);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOptionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.cairo(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.white.withValues(alpha: 0.03),
    );
  }


  Future<void> _saveImage(BuildContext context, ImageItem item) async {
    debugPrint("📥 Saving image from: ${item.originalUrl ?? item.link}");
    try {
      final imageUrl = item.originalUrl ?? item.link;
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        String ext = '.jpg';
        if (imageUrl.toLowerCase().contains('.png')) ext = '.png';
        if (imageUrl.toLowerCase().contains('.webp')) ext = '.webp';
        if (imageUrl.toLowerCase().contains('.gif')) ext = '.gif';
        
        final file = File('${tempDir.path}/save_${DateTime.now().millisecondsSinceEpoch}$ext');
        await file.writeAsBytes(response.bodyBytes);

        await Gal.putImage(file.path);
        debugPrint("✅ Image saved successfully!");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("✅ تم حفظ الصورة في معرض الصور"),
                backgroundColor: Colors.green),
          );
        }
      } else {
        debugPrint("❌ Failed to download image from $imageUrl: HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Save error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ فشل حفظ الصورة: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeInChat(BuildContext context, ImageItem item) async {
    final imageUrl = item.originalUrl ?? item.link;
    if (imageUrl.isEmpty) return;

    // 💡 Show quick loading feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🧪 جاري جلب الصورة لبدء التحليل في المحادثة..."),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // 1. Download image to temporary file
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/analyze_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);

        if (!context.mounted) return;
        Navigator.pop(context); // Close gallery preview

        // 2. Call AI Orchestrator with the downloaded file
        final orchestrator = Get.find<AIOrchestrator>();
        await orchestrator.processUserInput(
          images: [file],
         
        );
      }
    } catch (e) {
      debugPrint("❌ Analyze in Chat Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ فشل التحليل: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _lensSearch(BuildContext context, ImageItem item) {

    final lensUrl = item.originalUrl ?? item.link;
    debugPrint("🔍 Triggering Lens Search for: $lensUrl");
    Navigator.pop(context); // Close preview
    final orchestrator = Get.find<AIOrchestrator>();
    orchestrator.processUserInput(
      text: "ابحث عن هذا المنتج باستخدام العدسة الذكية: $lensUrl",
    );
  }

  void _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
