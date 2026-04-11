import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../services/media/youtube_stream_service.dart';
import '../services/tiktok_service.dart';
import '../services/serpapi_services.dart';
import '../controllers/settings_controller.dart';
import '../widgets/social/social_profile_dashboard.dart';
class TrendScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final String? title;
  final List<String>? suggestedActions;

  const TrendScreen({
    super.key, 
    required this.videos, 
    this.title,
    this.suggestedActions,
  });

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  late PageController _pageController;
  final RxInt _activeVideoIndex = 0.obs;
  
  // 🎬 Smart Preloading Players
  final Map<int, Player> _activePlayers = {};
  final Map<int, VideoController> _activeControllers = {};

  // 📊 Reactive State (V5.0)
  late RxList<Map<String, dynamic>> _currentVideosList;
  final RxList<Map<String, dynamic>> _suggestedProductsList = <Map<String, dynamic>>[].obs;
  final RxBool _showProductsOverlay = false.obs;
  final RxMap<int, bool> _isLoadingMap = <int, bool>{}.obs;
  final RxMap<int, String> _playbackErrorMap = <int, String>{}.obs;
  final RxMap<int, bool> _isYoutubeFallbackMap = <int, bool>{}.obs;
  final RxBool _isMyProfileMode = false.obs;
  final TextEditingController _searchController = TextEditingController();
  
  // 🎮 Playback Controls
  final RxBool _isVideoPaused = false.obs;
  final RxDouble _playbackSpeed = 1.0.obs;
  final List<double> _speedOptions = [1.0, 1.5, 2.0];
  
  // 🏷️ Category Filter
  final RxString _activeCategory = ''.obs;
  final List<Map<String, dynamic>> _categories = [
    {'label': 'الكل', 'icon': Icons.whatshot, 'query': ''},
    {'label': 'إلكترونيات', 'icon': Icons.devices, 'query': 'electronics gadgets'},
    {'label': 'موسيقى', 'icon': Icons.music_note, 'query': 'music'},
    {'label': 'مسلسلات', 'icon': Icons.movie, 'query': 'series drama'},
    {'label': 'طبخ', 'icon': Icons.restaurant, 'query': 'cooking recipe'},
    {'label': 'رياضة', 'icon': Icons.sports_soccer, 'query': 'sports fitness'},
    {'label': 'تعليم', 'icon': Icons.school, 'query': 'education tutorial'},
    {'label': 'كوميديا', 'icon': Icons.emoji_emotions, 'query': 'comedy funny'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize list and filter duplicates
    _currentVideosList = widget.videos.obs;
    _currentVideosList.value = _currentVideosList.toSet().toList();

    // Auto-play first video or initialize mixed random feed
    if (_currentVideosList.isNotEmpty) {
      _manageVideoLifecycle(0);
    } else {
      _initializeRandomFeed();
    }

    // 🚀 Plan 1 & 3: Auto-trigger context search after delay
    if (widget.title != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _submitInFeedSearch("أفضل سعر لـ: ${widget.title}", silent: true, actionId: 'amazon');
        }
      });
    }
  }

  Future<void> _manageVideoLifecycle(int currentIndex) async {
    // 1. Dispose old players
    final keys = _activePlayers.keys.toList();
    for (final index in keys) {
      if ((index - currentIndex).abs() > 2) {
        _activePlayers[index]?.dispose();
        _activePlayers.remove(index);
        _activeControllers.remove(index);
        _isLoadingMap.remove(index);
        _playbackErrorMap.remove(index);
        debugPrint("🗑️ Disposed Player at index: $index to save RAM");
      }
    }

    // 2. Preload current + next 2
    for (int i = currentIndex; i <= currentIndex + 2; i++) {
      if (i < _currentVideosList.length && !_activePlayers.containsKey(i)) {
        await _setupPlayerAtIndex(i);
      }
    }

    // 3. Play current, pause others
    _activePlayers.forEach((index, player) {
      if (index == currentIndex) {
        player.play();
        debugPrint("▶️ Playing Video: $index");
      } else {
        player.pause();
      }
    });
  }

  Future<void> _setupPlayerAtIndex(int index) async {
    final videoData = _currentVideosList[index];
    final originalUrl = videoData['clip'] ?? '';
    
    // ✅ التحقق من روابط Direct Streams بما في ذلك روابط Instagram (fbcdn.net)
    final isDirectStream = originalUrl.endsWith('.mp4') || 
                           originalUrl.endsWith('.m3u8') || 
                           originalUrl.contains('fbcdn.net') || 
                           originalUrl.contains('.mp4?');
                           
    String playUrl = originalUrl;

    final player = Player();
    final controller = VideoController(player);
    _activePlayers[index] = player;
    _activeControllers[index] = controller;
    
    player.setPlaylistMode(PlaylistMode.loop);
    _isLoadingMap[index] = true;
    _playbackErrorMap[index] = "";

    try {
      if (!isDirectStream) {
        // 🚀 1. دعم TikTok و Instagram (تم التحويل للويب مباشرة للحصول على الواجهة الأصلية)
        if (originalUrl.contains("tiktok.com") || originalUrl.contains("instagram.com")) {
          _isYoutubeFallbackMap[index] = true;
          return; // نتوقف هنا لأن الـ WebView سيتكفل بالباقي
        } 
        // 🚀 2. دعم YouTube
        else if (originalUrl.contains("youtube.com") || originalUrl.contains("youtu.be")) {
          final directUrl = await Get.find<YoutubeStreamService>().getDirectStreamUrl(originalUrl);
          if (directUrl != null && directUrl.isNotEmpty) {
            playUrl = directUrl;
          } else {
            throw Exception("Direct YouTube stream not found");
          }
        }
      }

      if (!mounted) return;
      
      await player.open(Media(playUrl), play: false);
      debugPrint("📥 Preloaded Video at index: $index");
      
      if (_activeVideoIndex.value == index) {
        player.play();
      }
    } catch (e) {
      debugPrint("⚡ Direct Stream Fail - Switching to Embed Fallback for $index");
      _isYoutubeFallbackMap[index] = true;
      _playbackErrorMap[index] = "لا يمكن التشغيل المباشر";
    } finally {
      if (mounted) _isLoadingMap[index] = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final player in _activePlayers.values) {
      player.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() => Stack(
        fit: StackFit.expand,
        children: [
          // ------------------------------------------------------------------
          // 1. الطبقة الأساسية: فيديو عمودي (TikTok Style Video Feed)
          // ------------------------------------------------------------------
          if (_currentVideosList.isEmpty)
            _buildEmptyState()
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _currentVideosList.length,
              onPageChanged: (index) {
                _activeVideoIndex.value = index;
                _manageVideoLifecycle(index);
              },
              itemBuilder: (context, index) {
                final video = _currentVideosList[index];
                return Obx(() => _buildFeedItem(video, index, index == _activeVideoIndex.value));
              },
            ),

          // ------------------------------------------------------------------
          // 2. الطبقة العلوية الزجاجية: زر الرجوع والعنوان (Top Glass Bar)
          // ------------------------------------------------------------------
          _buildTopBar(),

          // ------------------------------------------------------------------
          // 3. طبقة المنتجات المقترحة (Overlay Products) - تظهر عند البحث
          // ------------------------------------------------------------------
          if (_showProductsOverlay.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 90, // فوق شريط البحث
              child: _buildProductsOverlayPanel(),
            ),

          // ------------------------------------------------------------------
          // 4. طبقة حقل الدردشة والبحث الزجاجي المدمج (Bottom Search Bar)
          // ------------------------------------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGlassSearchBar(context),
          ),
        ],
      )),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_filter_outlined, color: Colors.white.withValues(alpha: 0.2), size: 100),
          const SizedBox(height: 16),
          const Text(
            "لم نتمكن من العثور على تريندات حالياً 🔍",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("العودة للدردشة"),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> video, int index, bool isActive) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. طبقة الوسائط (الفيديو أو الويب)
        GestureDetector(
          onTap: () => _togglePlayPause(index),
          child: _buildMediaLayer(video, index, isActive),
        ),

        // 2. تراكب التدرج اللوني (Gradient) لسهولة قراءة النصوص
        _buildGradientOverlay(),

        // 3. التحكم بالتشغيل (أيقونة Play الكبيرة)
        if (isActive) _buildPlaybackControls(index),

        // 4. فئات البحث (Chips)
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: 0,
          right: 0,
          child: _buildCategoryChips(),
        ),

        // 5. الأزرار الذكية الجانبية
        Positioned(
          right: 16,
          bottom: 150,
          child: _buildSmartActions(video),
        ),

        // 6. معلومات الفيديو (العنوان والحساب)
        Positioned(
          left: 16,
          bottom: 110,
          right: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlatformBadge(video),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildVideoInfo(video)),
                  if (video['duration'] != null)
                    _buildDurationBadge(video['duration'].toString()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 🛠️ بناء طبقة الوسائط (الفيديو أو الويب)
  Widget _buildMediaLayer(Map<String, dynamic> video, int index, bool isActive) {
    if (!isActive) {
      // عرض الصورة المصغرة للفيديوهات غير النشطة لتوفير الموارد
      final thumb = video['thumbnail'] ?? video['thumbnail_url'] ?? '';
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => 
            const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 60)),
      );
    }

    final url = video['clip'] ?? video['videoUrl'] ?? video['link'] ?? '';
    final isSocial = url.contains('instagram.com') || url.contains('tiktok.com');
    
    // 💡 القرار الذكي للفيد الموحد: 
    // 1. إنستقرام وتيك توك -> نستخدم الـ ويب دائماً لنحصل على الواجهة الأصلية (Likes/Follow)
    // 2. يوتيوب -> نستخدم المشغل الأصلي (Native) لأنه أسرع ويدعم التحكم بالحجم
    final showWebView = isSocial || (_isYoutubeFallbackMap[index] ?? false);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 🚀 الخيار 1: عرض الويب (للتواصل الاجتماعي أو في حال فشل الاستخراج)
        if (showWebView)
          Positioned.fill(
            child: _WebViewVideoPlayer(
              key: ValueKey('web_$url'),
              url: url,
            ),
          )
            
        // 🚀 الخيار 2: عرض المشغل الأصلي (ليوتيوب فقط حالياً)
        else if (_activeControllers.containsKey(index))
          Center(
            child: Video(
              key: ValueKey('native_$url'),
              controller: _activeControllers[index]!,
              fit: BoxFit.cover,
              controls: NoVideoControls,
            ),
          )
        
        // 🚀 الخيار 3: حالة التحميل
        else
          _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
  }


  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildSmartActions(Map<String, dynamic> video) {
    final title = video['title'] ?? 'منتج';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGlassButton(
          icon: Icons.document_scanner_outlined,
          label: 'فحص',
          color: const Color(0xFF00FFEE),
          onTap: () => _submitInFeedSearch("فحص جنائي دقيق لـ: $title", actionId: "lens"),
        ),
        const SizedBox(height: 18),
        _buildGlassButton(
          icon: Icons.shopping_bag_outlined,
          label: 'السعر',
          color: const Color(0xFFFFAA00),
          onTap: () => _submitInFeedSearch("أفضل سعر لـ: $title", actionId: "amazon"),
        ),
        const SizedBox(height: 18),
        _buildGlassButton(
          icon: Icons.trending_up,
          label: 'تريند',
          color: const Color(0xFF00FF88),
          onTap: () => _submitInFeedSearch("تحليل التريند لـ: $title", actionId: "trends"),
        ),
        const SizedBox(height: 18),
        _buildGlassButton(
          icon: Icons.reply, // Use reply icon mirrored for share if share not available, but share_rounded is standard. We will use share.
          label: 'مشاركة',
          color: Colors.white,
          onTap: () => _shareVideo(video),
        ),
      ],
    );
  }

  Future<void> _shareVideo(Map<String, dynamic> video) async {
    HapticFeedback.lightImpact();
    
    // 💡 Pause active player to prevent UI thread lock/OpenGL collisions during Share Intent
    if (_activePlayers.containsKey(_activeVideoIndex.value)) {
      _activePlayers[_activeVideoIndex.value]?.pause();
    }
    
    // Give Android UI Thread a tiny moment to settle before launching external Activity
    await Future.delayed(const Duration(milliseconds: 150));

    final url = video['clip'] ?? video['link'] ?? '';
    final shareTitle = video['title'] ?? 'فيديو مميز';
    if (url.isNotEmpty) {
      // ignore: deprecated_member_use
      await Share.share('شاهد هذا التريند 🚀\n$shareTitle\n$url');
    } else {
      Get.snackbar('عذراً', 'لا يوجد رابط لمشاركة هذا الفيديو',
          backgroundColor: Colors.black87, colorText: Colors.white);
    }
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'IBMPlexSansArabic',
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🎮 Playback Controls (Play/Pause + Speed)
  // ═══════════════════════════════════════════════════════════

  void _togglePlayPause(int index) {
    final player = _activePlayers[index];
    if (player == null) return;
    HapticFeedback.lightImpact();
    if (player.state.playing) {
      player.pause();
      _isVideoPaused.value = true;
    } else {
      player.play();
      _isVideoPaused.value = false;
    }
  }

  void _cycleSpeed(int index) {
    final player = _activePlayers[index];
    if (player == null) return;
    HapticFeedback.mediumImpact();
    final currentIdx = _speedOptions.indexOf(_playbackSpeed.value);
    final nextIdx = (currentIdx + 1) % _speedOptions.length;
    _playbackSpeed.value = _speedOptions[nextIdx];
    player.setRate(_playbackSpeed.value);
  }

  Widget _buildPlaybackControls(int index) {
    return Obx(() {
      final paused = _isVideoPaused.value;
      final speed = _playbackSpeed.value;

      return Stack(
        children: [
          // ▶️ Center Play/Pause indicator (fades after tap)
          if (paused)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),

          // ⏩ Speed Button (Bottom-Left)
          Positioned(
            left: 16,
            bottom: 180,
            child: GestureDetector(
              onTap: () => _cycleSpeed(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${speed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 📊 Profile Insights (JSON-Powered Analytics)
          Positioned(
            right: 16,
            bottom: 180,
            child: GestureDetector(
              onTap: () => _showProfileInsights(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showProfileInsights(int index) {
     final video = _currentVideosList[index];
     final clipUrl = video['clip']?.toString().toLowerCase() ?? '';
     
     // 🚀 الأولويّة القصوى لاكتشاف المنصة من الرابط مباشرة لمنع الـ Default الخطأ
     String platform = 'facebook';
     if (clipUrl.contains('instagram.com')) {
       platform = 'instagram';
     } else if (clipUrl.contains('tiktok.com')) {
       platform = 'tiktok';
     } else if (video['platform'] != null) {
       platform = video['platform'];
     }

     // 🚀 استخراج المعرّف: لضمان جلب البيانات الصحيحة، نفضل اسم المؤلف (Username) دائماً للفيديوهات
     String profileId = '';
     
     // إذا كان رييل، اسم المؤلف من البيانات الوصفية هو الأدق
     if (clipUrl.contains('/reel/') || clipUrl.contains('/video/') || clipUrl.contains('/reels/')) {
        profileId = video['author'] ?? '';
     } else {
        profileId = _extractProfileId(clipUrl, platform);
     }
     
     // تنظيف الـ ID من أي زوائد أو "حساب غير معروف"
     if (profileId.isEmpty || profileId == 'حساب غير معروف' || profileId.length > 25) {
        profileId = video['author'] ?? '';
     }

     if (profileId.isNotEmpty && profileId != 'حساب غير معروف') {
       HapticFeedback.mediumImpact();
       Get.bottomSheet(
         SocialProfileDashboard(platform: platform, profileId: profileId),
         isScrollControlled: true,
         backgroundColor: Colors.transparent,
       );
     } else {
       Get.snackbar(
         'تنبيه', 
         'لم نتمكن من تحديد اسم الحساب لهذا الفيديو للأسف.',
         snackPosition: SnackPosition.BOTTOM,
         backgroundColor: Colors.black54,
         colorText: Colors.white,
       );
     }
  }

  String _extractProfileId(String url, String platform) {
    try {
      final lowUrl = url.toLowerCase();
      if (lowUrl.contains('instagram.com/')) {
         final parts = lowUrl.split('instagram.com/')[1].split('/');
         // تخمين اسم المستخدم إذا كان الرابط instagram.com/username/
         if (parts.isNotEmpty && !['reel', 'reels', 'p', 'tv', 'stories'].contains(parts[0])) {
           return parts[0];
         }
         // إذا كان رييل، فنحن نحتاج لاسم المؤلف من البيانات الوصفية (Author) وليس الـ ID من الرابط
      }
      if (lowUrl.contains('facebook.com/')) {
         final parts = lowUrl.split('facebook.com/')[1].split('/');
         if (parts.isNotEmpty) return parts[0];
      }
      if (lowUrl.contains('tiktok.com/@')) {
         final parts = lowUrl.split('tiktok.com/@')[1].split('/');
         if (parts.isNotEmpty) return parts[0];
      }
    } catch (_) {}
    return '';
  }

  // ═══════════════════════════════════════════════════════════
  //  🏷️ Category Filter Chips
  // ═══════════════════════════════════════════════════════════

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: Obx(() {
        // 🔑 Read observable at top level so GetX registers it
        final currentCategory = _activeCategory.value;
        
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final isActive = currentCategory == cat['query'];

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _activeCategory.value = cat['query'];
                final q = cat['query'] as String;
                if (q.isEmpty) {
                  _initializeRandomFeed();
                } else {
                  _submitInFeedSearch('$q shorts');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.red.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? Colors.redAccent : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat['icon'] as IconData, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildVideoInfo(Map<String, dynamic> video) {
    final String url = (video['clip'] ?? video['link'] ?? '').toString().toLowerCase();
    IconData pIcon = Icons.public;
    Color pColor = Colors.white70;
    
    if (url.contains('tiktok.com')) { pIcon = Icons.music_note; pColor = Colors.cyanAccent; }
    else if (url.contains('youtube.com') || url.contains('youtu.be')) { pIcon = Icons.play_circle_fill; pColor = Colors.redAccent; }
    else if (url.contains('instagram.com')) { pIcon = Icons.camera_alt; pColor = Colors.pinkAccent; }
    else if (url.contains('facebook.com')) { pIcon = Icons.facebook; pColor = Colors.blueAccent; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // 👤 Channel Avatar or Platform Icon
            if (video['channel_thumbnail'] != null && video['channel_thumbnail'].toString().isNotEmpty)
              Container(
                width: 24, height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                  image: DecorationImage(image: NetworkImage(video['channel_thumbnail']), fit: BoxFit.cover),
                ),
              )
            else if (video['source_icon'] != null && video['source_icon'].toString().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(video['source_icon'], width: 16, height: 16, errorBuilder: (_, __, ___) => Icon(pIcon, size: 16, color: pColor)),
              )
            else
              Icon(pIcon, size: 16, color: pColor),
            
            const SizedBox(width: 4),
            Text(
              video['author'] ?? video['channel'] ?? 'حساب غير معروف',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 4)]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          video['title'] ?? 'فيديو رائج',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3, fontFamily: 'IBMPlexSansArabic'),
        ),
      ],
    );
  }

  Widget _buildPlatformBadge(Map<String, dynamic> video) {
    final platform = video['platform']?.toString().toLowerCase() ?? 'web';
    IconData icon = Icons.public;
    Color color = Colors.white;
    String label = platform.toUpperCase();

    if (platform == 'youtube') { icon = Icons.play_circle_fill; color = Colors.red; label = 'YouTube'; }
    else if (platform == 'tiktok') { icon = Icons.music_note; color = Colors.cyanAccent; label = 'TikTok'; }
    else if (platform == 'instagram') { icon = Icons.camera_alt; color = Colors.pinkAccent; label = 'Instagram'; }
    else if (platform == 'facebook') { icon = Icons.facebook; color = Colors.blueAccent; label = 'Facebook'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildDurationBadge(String duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        duration,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(), 
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      widget.title ?? "التريندات الذكية",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'IBMPlexSansArabic'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Obx(() {
                  final settings = Get.find<SettingsController>();
                  if (settings.tiktokUsername.value.isEmpty) {
                    return const Icon(Icons.live_tv, color: Colors.white24, size: 24);
                  }
                  
                  return GestureDetector(
                    onTap: _toggleProfileMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isMyProfileMode.value 
                          ? const Color(0xFFFF0050) 
                          : Colors.white10,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isMyProfileMode.value ? Icons.person : Icons.public,
                            color: Colors.white,
                            size: 16,
                          ),
                          if (_isMyProfileMode.value) ...[
                            const SizedBox(width: 6),
                            const Text(
                              "حسابي",
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  final text = _searchController.text.trim();
                  if (text.isNotEmpty) {
                    _submitInFeedSearch(text);
                    _searchController.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF00FF88).withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF00FF88), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: "ابحث عن YouTube Shorts...",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'IBMPlexSansArabic'),
                      
                      
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (query) {
                      _submitInFeedSearch(query);
                      _searchController.clear();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsOverlayPanel() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 140,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("🛍️ المنتجات المقترحة لك", style: TextStyle(color: Color(0xFFFFAA00), fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'IBMPlexSansArabic')),
                  GestureDetector(onTap: () => _showProductsOverlay.value = false, child: const Icon(Icons.close, color: Colors.white54, size: 20)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedProductsList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final product = _suggestedProductsList[index];
                    return _buildProductCard(product);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      width: 260,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            child: Image.network(
              product['image'] ?? 'https://via.placeholder.com/150',
              width: 70, height: 70, fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(width: 70, height: 70, color: Colors.white10, child: const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2)));
              },
              errorBuilder: (context, error, stackTrace) => 
                  Container(width: 70, height: 70, color: Colors.white10, child: const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(product['title'] ?? 'منتج', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(product['price'] ?? 'سعر متنوع', style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  void _submitInFeedSearch(String query, {bool silent = false, String? actionId}) {
    HapticFeedback.mediumImpact();
    
    if (actionId == 'amazon' || query.contains('سعر')) {
      _fetchMockProducts(query);
      if (!silent) _showProductsOverlay.value = true;
      return; 
    }

    // 🎯 All searches go through YouTube directly (like real YouTube)
    _fetchDirectTrends(query);
  }

  Future<void> _fetchDirectTrends(String query) async {
    try {
      // Clean query text
      String cleanQuery = query.replaceFirst('تحليل التريند لـ: ', '').trim();
      if (cleanQuery.isEmpty) cleanQuery = 'trending shorts';

      Get.snackbar(
        '🔍 جاري البحث في YouTube',
        cleanQuery,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );

      final youtubeSearch = YoutubeSearchService();
      final results = await youtubeSearch.searchVideos(cleanQuery);
      
      if (results.isNotEmpty) {
        // Pause active players
        for (var controller in _activePlayers.values) {
          controller.pause();
        }
        
        // Refresh Feed completely
        _currentVideosList.assignAll(results);
        _activeVideoIndex.value = 0;
        
        // Trigger initialization of new videos
        _manageVideoLifecycle(0);
        
        Get.snackbar(
          '🔥 تم الجلب!', 
          'شاهد أحدث التريندات لـ $cleanQuery',
          backgroundColor: const Color(0xFF00FF88).withValues(alpha: 0.9),
          colorText: Colors.black,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar('عذراً', 'لم نجد تريندات حصرية بهذا الاسم حالياً', backgroundColor: Colors.orange);
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void _fetchMockProducts(String query) {
    _suggestedProductsList.value = [
      {
        "title": "منتج أصلي فاخر",
        "price": "350.00 ر.س",
        "image": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80"
      },
      {
        "title": "إصدار برو المطور",
        "price": "420.00 ر.س",
        "image": "https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=400&q=80"
      },
    ];
  }

  Future<void> _initializeRandomFeed() async {
    try {
      _currentVideosList.clear();
      _isLoadingMap.addAll({0: true}); // Fake load just for UI
      
      final results = await Get.find<GoogleShortVideosService>().getShortVideos('trending instagram reels tiktok shorts');
      
      if (results.isNotEmpty) {
        // Convert to list of maps and shuffle
        final list = results.map((v) => {
          'title': v['title'],
          'clip': v['link'],
          'source': v['source'],
          'source_icon': v['source_icon'] ?? '',
        }).toList();
        
        list.shuffle();
        _currentVideosList.assignAll(list);
        
        // Reset state
        _activeVideoIndex.value = 0;
        _isYoutubeFallbackMap.clear();
        _playbackErrorMap.clear();
        
        // Start engine
        _manageVideoLifecycle(0);
      } else {
        // Final fallback to dead links if API fails
        _setStaticFallbackFeed();
      }
    } catch (e) {
      debugPrint("❌ Trends Init Error: $e");
      _setStaticFallbackFeed();
    }
  }

  /// 🔄 التبديل بين الوضع المخصص والعام
  void _toggleProfileMode() async {
    _isMyProfileMode.toggle();
    _currentVideosList.clear();
    
    // إيقاف جميع المشغلات الحالية
    for (var player in _activePlayers.values) {
      player.stop();
      player.dispose();
    }
    _activePlayers.clear();
    _activeControllers.clear();
    
    if (_isMyProfileMode.value) {
      final settings = Get.find<SettingsController>();
      _isLoadingMap[0] = true;
      
      try {
        final hasTikTok = settings.tiktokUsername.value.isNotEmpty;
        final hasInstagram = settings.instagramUsername.value.isNotEmpty;

        if (hasTikTok) {
          final tiktok = TikTokService();
          final videos = await tiktok.fetchUserVideos(username: settings.tiktokUsername.value);
          if (videos.isNotEmpty) {
             _currentVideosList.assignAll(videos);
             _manageVideoLifecycle(0);
          } else if (hasInstagram) {
             _loadInstagramStore(settings.instagramUsername.value);
          }
        } else if (hasInstagram) {
          _loadInstagramStore(settings.instagramUsername.value);
        } else {
          _isMyProfileMode.value = false;
          _initializeRandomFeed();
          Get.snackbar('تنبيه', 'يرجى ربط حساب في الإعدادات أولاً');
        }
      } catch (e) {
        _isMyProfileMode.value = false;
        _initializeRandomFeed();
      } finally {
        _isLoadingMap[0] = false;
      }
    } else {
      _initializeRandomFeed();
    }
  }

  void _loadInstagramStore(String username) {
    _currentVideosList.assignAll([{
      'title': 'متجري (Indexes Store)',
      'clip': 'https://www.instagram.com/$username/reels/',
      'platform': 'instagram',
      'source': 'Instagram Profile',
    }]);
    _manageVideoLifecycle(0);
  }

  void _setStaticFallbackFeed() {
    List<Map<String, dynamic>> mixedTrends = [
      {
        "title": "تريند عالمي 🚀",
        "clip": "https://www.youtube.com/shorts/p4X_KMB0wos",
        "platform": "youtube"
      },
      {
        "title": "شورتس يوتيوب ✨",
        "clip": "https://www.youtube.com/shorts/Vv-0VrFkbT4",
        "platform": "youtube"
      },
    ];
    mixedTrends.shuffle();
    _currentVideosList.assignAll(mixedTrends);
    _manageVideoLifecycle(0);
  }
}


class _WebViewVideoPlayer extends StatefulWidget {
  final String url;
  const _WebViewVideoPlayer({super.key, required this.url});

  @override
  State<_WebViewVideoPlayer> createState() => _WebViewVideoPlayerState();
}

class _WebViewVideoPlayerState extends State<_WebViewVideoPlayer> {
  WebViewController? _controller;
  bool _isUnsupportedPlatform = false;
  bool _hasError = false; // 🚩 تعقب فشل التحميل
  String _targetEmbedUrl = "";
  static DateTime? _lastGlobalOverlayTime; // 🚀 تتبع عالمي لمنع تكرار الإزعاج في الجلسة
  String _lastUrlWithOverlay = ""; // 🚩 تتبع آخر رابط تم إظهار النافذة له

  String _getEmbedUrl(String originalUrl) {
    if (originalUrl.contains('instagram.com')) {
      if (originalUrl.endsWith('/embed') || originalUrl.endsWith('/embed/')) return originalUrl;
      return '${originalUrl.replaceAll(RegExp(r'/$'), '')}/embed';
    } else if (originalUrl.contains('tiktok.com')) {
      final uri = Uri.tryParse(originalUrl);
      if (uri != null && uri.pathSegments.contains('video')) {
        final videoId = uri.pathSegments.last;
        return 'https://www.tiktok.com/embed/v2/$videoId';
      }
    } else if (originalUrl.contains('facebook.com') && originalUrl.contains('reel')) {
      return 'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(originalUrl)}&show_text=false';
    } else if (originalUrl.contains('youtube.com') || originalUrl.contains('youtu.be')) {
      // 🎬 استخراج معرف الفيديو وتحويله لرابط embed
      final videoId = _extractYoutubeId(originalUrl);
      if (videoId != null) {
        return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&playsinline=1&controls=0&loop=1&rel=0&modestbranding=1';
      }
    }
    return originalUrl;
  }

  /// استخراج معرف يوتيوب من أنواع مختلفة من الروابط
  String? _extractYoutubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu.be/|youtube.com/shorts/)([^"&?/\s]{11})',
      caseSensitive: false,
    );
    return regExp.firstMatch(url)?.group(1);
  }

  @override
  void initState() {
    super.initState();
    
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _isUnsupportedPlatform = true;
        _launchExternal(widget.url);
        return;
      }

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        // 🚀 استخدام هوية iPhone 16.6 لإظهار أزرار الإعجاب والمتابعة بشكل كامل (High Fidelity)
        ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1")
        ..addJavaScriptChannel(
          'AuthBridge', // 🚀 جسر التواصل الجديد للمزامنة
          onMessageReceived: (message) {
            final currentUrl = widget.url;
            final now = DateTime.now();
            final isRecentlyShown = _lastGlobalOverlayTime != null && 
                                  now.difference(_lastGlobalOverlayTime!).inMinutes < 5;

            if (message.message == 'NOT_LOGGED_IN' && mounted && !isRecentlyShown && _lastUrlWithOverlay != currentUrl) {
               _lastGlobalOverlayTime = now; // 🚀 تحديث توقيت الإظهار العالمي
               _lastUrlWithOverlay = currentUrl; 
               _showSmartLoginOverlay();
            }
            debugPrint("🔐 Auth status: ${message.message} | URL: $currentUrl | RecentlyShown: $isRecentlyShown");
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              final url = widget.url.toLowerCase();
              final isSocial = url.contains('instagram.com') || url.contains('tiktok.com');
              if (error.isForMainFrame == true && mounted && !isSocial) {
                setState(() => _hasError = true);
              }
            },
            onPageFinished: (url) {
              // 🚀 حقن كود "التعرف الذكي" (Smart Detection)
              _controller?.runJavaScript('''
                (function() {
                  function auditAndClean() {
                    // 1. تنظيف ذكي للبنرات (الهيدر، الفوتر، زر فتح التطبيق، والملصقات)
                    const selectorsToHide = 'nav, footer, .upsell, .x9f619.x1n2onr6.x1ja2u2z, button[aria-label="Open in App"], .x1yk9m2, .x13d9t7u, [role="dialog"], [role="banner"]';
                    document.querySelectorAll(selectorsToHide).forEach(el => {
                       el.style.setProperty('display', 'none', 'important');
                    });
                    
                    // 🚀 إخفاء الحواجز التي تمنع التمرير وتطلب تسجيل الدخول فوراً (Surgical v3.0)
                    const overlays = [
                      'div[style*="background-color: rgba(0, 0, 0, 0.5)"]',
                      'div[style*="z-index: 1000"]',
                      '[role="presentation"]',
                      '[aria-label*="تسجيل"]',
                      '[aria-label*="Login"]',
                      '.xix79h9',
                      '.x1npaat5'
                    ].join(',');
                    
                    document.querySelectorAll(overlays).forEach(el => {
                       if (el.innerText.includes('Log in') || el.innerText.includes('تسجيل') || el.innerText.includes('see more') || el.innerText.includes('Login')) {
                          el.style.setProperty('display', 'none', 'important');
                          // 🚀 أهم خطوة: فك قفل التمرير الذي يضعه إنستقرام لفرض الدخول
                          document.body.style.setProperty('overflow', 'auto', 'important'); 
                          document.documentElement.style.setProperty('overflow', 'auto', 'important');
                       }
                    });

                    // 2. فحص حالة الجلسة
                    const isLoggedIn = document.cookie.includes('sessionid') || 
                                     document.cookie.includes('tt_webid') ||
                                     document.cookie.includes('auth_token');
                    
                    if (typeof AuthBridge !== 'undefined') {
                       AuthBridge.postMessage(isLoggedIn ? 'LOGGED_IN' : 'NOT_LOGGED_IN');
                    }

                    // 3. تشغيل أي فيديو وفك كتم الصوت بقوة
                    document.querySelectorAll('video').forEach(v => {
                      v.muted = false;
                      v.style.setProperty('visibility', 'visible', 'important');
                      v.style.setProperty('opacity', '1', 'important');
                      v.play();
                    });
                  }
                  
                  // 🚀 مراقب التغييرات الحية (MutationObserver) لحذف البنرات فور ظهورها
                  if (!window._isWatching) {
                    window._isWatching = true;
                    const observer = new MutationObserver((mutations) => auditAndClean());
                    observer.observe(document.body, { childList: true, subtree: true });
                  }

                  // فحص أولي ودوري لضمان نظافة المحتوى
                  auditAndClean();
                  setTimeout(auditAndClean, 300); // 🚀 فحص سريع إضافي
                })();
              ''');
            },
          ),
        );


      if (_controller!.platform is AndroidWebViewController) {
        (_controller!.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
      }

      // 🛠️ تحميل الرابط الكامل بدلاً من الـ IFrame المقيد لضمان عمل "الصوت" وواجهة المستخدم الأصلية
      if (widget.url.contains('tiktok.com') || widget.url.contains('instagram.com') || widget.url.contains('facebook.com')) {
        _controller!.loadRequest(Uri.parse(widget.url));
      } 
      else if (widget.url.contains('youtube.com') || widget.url.contains('youtu.be')) {
        final videoId = _extractYoutubeId(widget.url);
        final ytHtml = '''
          <html style="margin:0;padding:0;background:#000;width:100%;height:100%;">
            <body style="margin:0;padding:0;width:100%;height:100%; pointer-events: none; display: flex; justify-content: center; align-items: center;">
              <iframe src="https://www.youtube.com/embed/$videoId?autoplay=1&mute=0&playsinline=1&controls=0&loop=1&playlist=$videoId" 
                      style="width:100vw; height:100vh; border:none;" 
                      allow="autoplay; fullscreen">
              </iframe>
            </body>
          </html>
        ''';
        _controller!.loadHtmlString(ytHtml);
      } 
      else {
        // للروابط الأخرى
        _targetEmbedUrl = _getEmbedUrl(widget.url);
        _controller!.loadRequest(Uri.parse(_targetEmbedUrl));
      }
    } catch (e) {
      _isUnsupportedPlatform = true;
    }
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 🚀 نافذة تسجيل الدخول الذكية (Smart Login Overlay)
  void _showSmartLoginOverlay() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 25),
            const Text("🔓 سجل دخولك للتفاعل", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'IBMPlexSansArabic')),
            const SizedBox(height: 12),
            const Text(
              "سجل الآن لتتمكن من الإعجاب والمتابعة والتعليق\nمباشرة من داخل تطبيق TrendScreen",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5, fontFamily: 'IBMPlexSansArabic'),
            ),
            const SizedBox(height: 30),
            
            _buildLoginOption(
              icon: Icons.g_mobiledata,
              label: "مزامنة سريعة عبر Google",
              color: const Color(0xFF4285F4),
              onTap: () {
                Get.back();
                debugPrint("🔄 Google Sync Triggered...");
              },
            ),
            
            const SizedBox(height: 15),
            
            _buildLoginOption(
              icon: Icons.camera_alt,
              label: "استخدام حساب Instagram / TikTok",
              color: Colors.white.withValues(alpha: 0.1),
              onTap: () => Get.back(),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildLoginOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (_isUnsupportedPlatform || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.open_in_browser, color: Colors.white54, size: 60),
            const SizedBox(height: 16),
            const Text(
              "جاري الفتح في المتصفح الخارجي...",
              style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'IBMPlexSansArabic'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        
        // 🚀 زر "الفتح في التطبيق" (Floating Action for Stability)
        Positioned(
          top: 10,
          right: 60,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchExternal(widget.url),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.launch, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _getPlatformName(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 50),
          const SizedBox(height: 16),
          const Text(
            "هذا الفيديو محمي أو غير متاح محلياً",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            child: Text(
              "سياسات التطبيق تمنع عرضه هنا، اضغط لمشاهدته في التطبيق الأصلي",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _launchExternal(widget.url),
            icon: Icon(_getPlatformIcon()),
            label: Text("الفتح في ${_getPlatformName()}"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPlatformPrimaryColor(),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ],
      ),
    );
  }

  String _getPlatformName() {
    final lowerUrl = widget.url.toLowerCase();
    if (lowerUrl.contains('instagram.com')) return "Instagram";
    if (lowerUrl.contains('tiktok.com')) return "TikTok";
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) return "YouTube";
    if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.watch')) return "Facebook";
    return "التطبيق الخارجي";
  }

  Color _getPlatformPrimaryColor() {
    final name = _getPlatformName();
    switch (name) {
      case "YouTube": return const Color(0xFFFF0000);
      case "TikTok": return const Color(0xFF00f2ea); // TikTok Cyan
      case "Instagram": return const Color(0xFFE1306C); // Instagram Pink
      case "Facebook": return const Color(0xFF1877F2); // Facebook Blue
      default: return const Color(0xFF00FF88); // Default Smart Green
    }
  }

  IconData _getPlatformIcon() {
    final name = _getPlatformName();
    switch (name) {
      case "YouTube": return Icons.play_circle_filled;
      case "TikTok": return Icons.music_note;
      case "Instagram": return Icons.camera_alt;
      case "Facebook": return Icons.facebook;
      default: return Icons.launch;
    }
  }
}
