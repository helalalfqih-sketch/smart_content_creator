import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/social_profile_controller.dart';

class SocialProfileDashboard extends GetView<SocialProfileController> {
  final String platform;
  final String profileId;

  const SocialProfileDashboard({
    super.key,
    required this.platform,
    required this.profileId,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SocialProfileController>()) {
      Get.put(SocialProfileController());
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.profileData.isEmpty || controller.profileData['id'] != profileId) {
        controller.loadProfile(platform, profileId);
      }
    });

    return Container(
      constraints: BoxConstraints(maxHeight: Get.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Column(
            children: [
              _buildHandle(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) return _buildLoadingState();
                  if (controller.errorMessage.isNotEmpty) return _buildErrorState();
                  final data = controller.profileData;
                  if (data.isEmpty) return const SizedBox();
                  return _buildProfileContent(data);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 100, height: 100, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(height: 20),
            Container(width: 150, height: 20, color: Colors.white),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) => Container(width: 80, height: 40, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          TextButton(
            onPressed: () => controller.loadProfile(platform, profileId),
            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> data) {
    final name = data['name'] ?? 'حساب غير معروف';
    final picture = data['profile_picture'] ?? '';
    final followers = data['followers'] ?? '0';
    final verified = data['verified'] ?? false;
    final bio = data['profile_intro_text'] ?? '';
    final photos = List<Map<String, dynamic>>.from(data['photos'] ?? []);
    final links = List<Map<String, dynamic>>.from(data['links'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Profile Header
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.purple, Colors.orange, Colors.yellow]),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: picture.isNotEmpty ? CachedNetworkImageProvider(picture) : null,
                  backgroundColor: Colors.white12,
                ),
              ),
              if (verified)
                const Icon(Icons.verified, color: Colors.blueAccent, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            platform.toUpperCase(),
            style: const TextStyle(color: Colors.white54, letterSpacing: 1.2, fontSize: 12),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('المتابعين', followers),
            _buildStatItem('يتابع', data['following'] ?? '0'),
            _buildStatItem('المنشورات', data['posts'] ?? '0'),
          ],
        ),

        const SizedBox(height: 30),
        
        // Bio Section
        if (bio.isNotEmpty) ...[
          const Text('عن الحساب', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(bio, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 24),
        ],

        // Links Row
        if (links.isNotEmpty) ...[
          const Text('روابط خارجية', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: links.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final link = links[index];
                return _buildLinkIcon(link['icon'] ?? '', link['link'] ?? '');
              },
            ),
          ),
          const SizedBox(height: 30),
        ],

        // Photos Grid
        if (photos.isNotEmpty) ...[
          const Text('معرض الصور', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: photos[index]['link'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.white12),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildLinkIcon(String iconUrl, String url) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: iconUrl.isNotEmpty 
          ? CachedNetworkImage(imageUrl: iconUrl, width: 24) 
          : const Icon(Icons.link, color: Colors.white54, size: 20),
      ),
    );
  }
}
