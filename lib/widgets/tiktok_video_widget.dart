import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../core/models/tiktok_video.dart';
import '../controllers/trend_controller.dart';
import '../theme/app_theme.dart';
import '../screens/ai_chat_screen.dart';
import 'tiktok_logo_icon.dart';

class TikTokVideoWidget extends StatelessWidget {
  final TikTokVideo video;

  const TikTokVideoWidget({super.key, required this.video});

  Future<void> _openTikTok() async {
    final url = 'https://www.tiktok.com/@${video.author}/video/${video.id}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark surface
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🎭 Animated Cover / Visual Part
          GestureDetector(
            onTap: _openTikTok,
            child: AspectRatio(
              aspectRatio: 16 / 10, // Wider preview for chat cards
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Base Thumbnail (Static)
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholder(),
                    errorWidget: (context, url, err) => _buildErrorWidget(),
                  ),

                  // 2. Animated Cover Overlay (Gif/WebP) - The "Alive" part
                  if (video.dynamicCoverUrl != null)
                    CachedNetworkImage(
                      imageUrl: video.dynamicCoverUrl!,
                      fit: BoxFit.cover,
                      // Fade in the animation over the static thumbnail
                      fadeInDuration: const Duration(milliseconds: 500),
                    ),

                  // 3. Gradient Overlay for Text Readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Play Icon & TikTok Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  ),

                  // Trending Badge
                  if (video.trendingPosition > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('#${video.trendingPosition} RISING',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 📝 Info Part
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  video.title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Author & Stats Row
                Row(
                  children: [
                    const TikTokLogoIcon(size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "@${video.author}",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    _buildQuickStat(Icons.remove_red_eye_outlined,
                        video.toMap()['views'] ?? '0'),
                    const SizedBox(width: 12),
                    _buildQuickStat(
                        Icons.favorite_border, video.toMap()['likes'] ?? '0'),
                  ],
                ),

                const SizedBox(height: 16),

                // ⚡ Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassButton(
                        label: "AI Studio",
                        icon: Icons.auto_awesome,
                        color: AppTheme.primary,
                        onTap: () {
                          Get.back();
                          Get.to(
                              () => AiChatScreen(initialMode: 'video_spark'));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.download_rounded,
                      onTap: () => _handleDownload(),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.share_rounded,
                      onTap: () {
                        // Share logic
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B2B2B), Color(0xFF1E1E1E)],
        ),
      ),
      child: const Center(
        child: TikTokLogoIcon(size: 40),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }

  void _handleDownload() {
    final trendController = Get.find<TrendController>();
    final videoUrl = video.videoUrl;

    if (videoUrl.isNotEmpty) {
      Get.defaultDialog(
        title: 'جاري التحميل',
        backgroundColor: const Color(0xFF1E1E1E),
        titleStyle: const TextStyle(color: Colors.white),
        content: Obx(() => Column(
              children: [
                LinearProgressIndicator(
                    value: trendController.downloadProgress.value,
                    color: AppTheme.primary),
                const SizedBox(height: 12),
                Text(
                  '${(trendController.downloadProgress.value * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            )),
      );

      trendController.startDownload(videoUrl).then((_) {
        if (Get.isDialogOpen ?? false) Get.back();
      });
    }
  }
}
