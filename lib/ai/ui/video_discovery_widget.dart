import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_models.dart';
import '../../core/models/tiktok_video.dart';

/// 🎞️ VideoDiscoveryWidget - A premium carousel for cross-platform video trends.
/// Displays TikTok, Instagram, and YouTube results in a unified, elegant layout.
class VideoDiscoveryWidget extends StatelessWidget {
  final VideoDiscoveryData data;
  final List<SuggestedAction>? actions;

  const VideoDiscoveryWidget({
    required this.data,
    this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final List<TikTokVideo> videos = data.videos
        .map((v) => TikTokVideo.fromJson(Map<String, dynamic>.from(v)))
        .toList();

    if (videos.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                data.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          
          SizedBox(
            height: 240, // Height for vertical-oriented video cards
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                return _VideoCard(video: videos[index]);
              },
            ),
          ),
          
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: Wrap(
                spacing: 8,
                children: actions!.map((a) => _buildActionButton(context, a)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SuggestedAction action) {
    return ActionChip(
      label: Text(action.label),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        // Handled by the agent controller via its standard action dispatcher
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final TikTokVideo video;

  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    final platform = _getPlatformInfo(video.videoUrl);
    
    return GestureDetector(
      onTap: () => _launchVideo(video.videoUrl),
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🖼️ Thumbnail
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.white10),
              errorWidget: (context, url, err) => Container(color: Colors.blueGrey),
            ),
            
            // 🌫️ Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            
            // 🏷️ Platform Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                   color: Colors.black.withValues(alpha: 0.5),
                   shape: BoxShape.circle,
                ),
                child:Icon(platform.icon, size: 14, color: platform.color),
              ),
            ),
            
            // 📝 Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, size: 10, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        TikTokVideo.formatViews(video.views),
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // ▶️ Play Indicator
            const Center(
              child: Icon(Icons.play_circle_filled_rounded, color: Colors.white60, size: 36),
            ),
          ],
        ),
      ),
    );
  }

  _PlatformInfo _getPlatformInfo(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('tiktok.com')) {
      return const _PlatformInfo(icon: Icons.video_collection_rounded, color: Colors.pinkAccent);
    } else if (lower.contains('instagram.com')) {
      return const _PlatformInfo(icon: Icons.camera_alt_rounded, color: Colors.purpleAccent);
    } else if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return const _PlatformInfo(icon: Icons.movie_creation_rounded, color: Colors.redAccent);
    }
    return const _PlatformInfo(icon: Icons.videocam_rounded, color: Colors.white);
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PlatformInfo {
  final IconData icon;
  final Color color;
  const _PlatformInfo({required this.icon, required this.color});
}
