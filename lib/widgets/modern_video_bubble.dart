import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'video_full_screen_viewer.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 🎬 مشغّل فيديو حديث داخل فقاعة الشات
/// مستوحى من واجهة Google Gemini
/// يدعم: Seekbar، أزرار مشاركة/تحميل، عرض الوقت
class ModernVideoBubble extends StatefulWidget {
  final String id;
  final String? videoPath;
  final String? thumbnailUrl;
  final bool isLocal;
  final double? progress;

  const ModernVideoBubble({
    super.key,
    required this.id,
    required this.videoPath,
    this.thumbnailUrl,
    this.isLocal = false,
    this.progress,
    this.onRefresh,
    this.isPending = false,
  });

  final VoidCallback? onRefresh;
  final bool isPending;

  @override
  State<ModernVideoBubble> createState() => _ModernVideoBubbleState();
}

class _ModernVideoBubbleState extends State<ModernVideoBubble>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isBuffering = false;
  String? _thumbnailPath;
  bool _isThumbnailLoading = true;
  bool _isSaving = false;
  bool _autoDownloadWhenReady = false;
  bool _isInitializing = false; // 🛡️ حارس التهيئة لمنع الـ Loop
  String? _lastInitializedPath; // 🛡️ تتبع الرابط الأخير لتمكين الحماية القصوى
  bool _isThumbnailGenerating = false; // 🛡️ حارس توليد الغلاف

  late AnimationController _controlsFadeController;
  late Animation<double> _controlsFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _controlsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controlsFade =
        Tween<double>(begin: 1.0, end: 0.0).animate(_controlsFadeController);

    // 🚀 بدء التهيئة بعد رندر الفريم الأول لضمان استقرار الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeVideo();
        _generateThumbnail();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isPlaying) {
        _togglePlay(); // Pause video when app is not in foreground
      }
    }
  }

  /// توليد غلاف للفيديو
  Future<void> _generateThumbnail() async {
    if (_isThumbnailGenerating || _thumbnailPath != null) {
      return;
    }
    
    try {
      _isThumbnailGenerating = true;
      if (widget.thumbnailUrl != null) {
        if (mounted) {
          setState(() {
            _isThumbnailLoading = false;
            _isThumbnailGenerating = false;
          });
        }
        return;
      }

      if (widget.videoPath == null || !widget.isLocal) {
        if (mounted) {
          setState(() {
            _isThumbnailLoading = false;
            _isThumbnailGenerating = false;
          });
        }
        return;
      }

      final String? fileName = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath!,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 85,
      );

      if (!mounted) return;
      setState(() {
        _thumbnailPath = fileName;
        _isThumbnailLoading = false;
        _isThumbnailGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThumbnailLoading = false;
        _isThumbnailGenerating = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    // 🛡️ حماية 0: منع التهيئة إذا لم تكن الشاشة مرئية أو المسار غير صحيح (للحفاظ على عتاد الجهاز)
    final currentRoute = Get.currentRoute;
    if (currentRoute != '/AiChatScreen' && 
        currentRoute != '/home' && 
        !currentRoute.contains('AiChatScreen')) {
      return;
    }

    if (widget.videoPath == null || widget.videoPath!.isEmpty) {
      debugPrint("🚫 [VideoBubble] Init Aborted: No Source for ${widget.id}");
      return;
    }
    
    // 🛡️ حماية 1: منع التهيئة المكررة إذا كانت العملية جارية
    if (_isInitializing) {
      return;
    }
    
    // 🛡️ حماية 2: إذا كان المشغل مهيأ بالفعل لنفس الرابط، لا تفعل شيئاً
    if (_isInitialized && _controller != null && _lastInitializedPath == widget.videoPath) {
      return;
    }

    try {
      if (!mounted) return;
      _isInitializing = true;
      
      // 🛡️ حماية 3: إذا كان الرابط هو نفسه الذي تم رندره للتو، تجاهل الطلب
      if (_lastInitializedPath == widget.videoPath && _isInitialized) {
        _isInitializing = false;
        return;
      }

      debugPrint("🎬 [VideoBubble] Starting protected initialization: ${widget.id} | Source: ${widget.videoPath}");

      // 1. Dispose old controller safely
      if (_controller != null) {
        final oldController = _controller!;
        _controller = null;
        // لا نحدث الحالة هنا لتجنب وميض الواجهة أثناء التغيير السريع
        await oldController.dispose();
      }
      
      final VideoPlayerController newController;
      if (widget.isLocal) {
        newController = VideoPlayerController.file(File(widget.videoPath!));
      } else {
        newController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath!));
      }

      _controller = newController;
      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        _isInitializing = false;
        _controller = null;
        return;
      }

      newController.addListener(_videoListener);

      setState(() {
        _isInitialized = true;
        _isPlaying = false;
        _isThumbnailLoading = false;
        _isInitializing = false; 
        _lastInitializedPath = widget.videoPath; // تثبيت الرابط الناجح
      });
      
      // 📥 تفعيل التحميل التلقائي إذا كان مطلوباً
      if (_autoDownloadWhenReady) {
        _autoDownloadWhenReady = false; // إعادة التعيين لمنع التكرار
        _saveVideo();
      }
      
      debugPrint("✅ [VideoBubble] Initialization complete and locked: ${widget.id}");
    } catch (e) {
      debugPrint("❌ [VideoBubble] Init Error: $e");
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isInitialized = false;
          _isThumbnailLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    // 🛡️ حماية المسار: إذا غادر المستخدم الشاشة، نوقف المعالجة فوراً
    final currentRoute = Get.currentRoute;
    if (currentRoute != '/AiChatScreen' && currentRoute != '/home' && !currentRoute.contains('AiChatScreen')) {
      if (_isPlaying) {
        _controller?.pause();
        _isPlaying = false;
      }
      return;
    }

    final controllerValue = _controller!.value;

    // Update buffering state
    if (controllerValue.isBuffering != _isBuffering) {
      setState(() => _isBuffering = controllerValue.isBuffering);
    }

    // Auto-reset when finished
    if (controllerValue.position >= controllerValue.duration &&
        controllerValue.duration > Duration.zero) {
      setState(() {
        _isPlaying = false;
        _showControls = true;
        _controlsFadeController.reverse();
        _controller?.seekTo(Duration.zero);
      });
    }

    // Update UI for seekbar only when playing
    if (_isPlaying && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ModernVideoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Case 1: Video path changed to a new valid path
    if (oldWidget.videoPath != widget.videoPath && widget.videoPath != null) {
      debugPrint("🎬 ModernVideoBubble: videoPath updated -> Re-initializing");
      _initializeVideo();
    } 
    // Case 2: Video path became null (e.g. error or cleared) -> Release resources
    else if (widget.videoPath == null && _controller != null) {
      debugPrint("🎬 ModernVideoBubble: videoPath became null -> Disposing controller");
      _disposeController();
    }
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      final oldController = _controller!;
      _controller = null;
      if (mounted) {
        setState(() => _isInitialized = false);
      }
      await oldController.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    _controlsFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPending || (widget.videoPath == null && widget.thumbnailUrl == null)) {
      return _buildGeneratingState();
    }

    // حالة التحميل الأولي
    if (!_isInitialized &&
        (widget.isLocal || _isThumbnailLoading) &&
        widget.thumbnailUrl == null) {
      return _buildLoadingState();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 450,
            maxWidth: 320,
            minHeight: 180,
          ),
          child: AspectRatio(
            aspectRatio:
                _isInitialized ? _controller!.value.aspectRatio : 16 / 9,
            child: GestureDetector(
              onTap: _onVideoTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 🎬 محتوى الفيديو / الغلاف
                  _buildMainContent(),

                  // 🎛️ طبقة التحكمات
                  AnimatedBuilder(
                    animation: _controlsFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _showControls ? 1.0 : _controlsFade.value,
                        child: _buildControlsOverlay(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// حالة التوليد (AI Generating)
  Widget _buildGeneratingState() {
    return Container(
      width: 320,
      height: 220, // زيادة الارتفاع قليلاً للزر الجديد
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.2 * value),
                          blurRadius: 15 * value,
                          spreadRadius: 2 * value,
                        )
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF00FF88),
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                '🎬 جاري التوليد الذكي... ${widget.progress != null ? "(${(widget.progress! * 100).toInt()}%)" : ""}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'يتم الآن تحريك المنتج بأحدث تقنيات الذكاء الاصطناعي 🚀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 📥 زر التحميل في الخلفية
              if (!_autoDownloadWhenReady)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _autoDownloadWhenReady = true);
                    Get.snackbar(
                      '📥 وضع الانتظار',
                      'سيتم تحميل الفيديو تلقائياً فور اكتمال التوليد 🚀',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF00FF88).withValues(alpha: 0.8),
                      colorText: Colors.black,
                      margin: const EdgeInsets.all(15),
                      borderRadius: 12,
                      icon: const Icon(Icons.downloading_rounded, color: Colors.black),
                    );
                  },
                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: const Text('تحميل عند الجاهزية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: const Color(0xFF00FF88),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'سيتم التحميل تلقائياً 📥',
                      style: TextStyle(color: const Color(0xFF00FF88).withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFF00FF88).withValues(alpha: 0.3),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// حالة التحميل
  Widget _buildLoadingState() {
    return Container(
      width: 300,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Color(0xFF00FF88),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'جاري تحميل الفيديو...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isInitialized && _controller != null) {
      debugPrint("📺 [VideoBubble] Rendering VideoPlayer for ${widget.id}");
      return VideoPlayer(_controller!);
    }
    
    if (widget.thumbnailUrl != null) {
      debugPrint("🖼️ [VideoBubble] Rendering Network Thumbnail for ${widget.id}");
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildLoadingState(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    }

    if (_thumbnailPath != null) {
      debugPrint("🖼️ [VideoBubble] Rendering Local Thumbnail for ${widget.id}");
      return Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !_isInitialized && !_isThumbnailLoading && widget.videoPath != null
                  ? Icons.error_outline_rounded
                  : Icons.movie_creation_outlined,
              color: (!_isInitialized && !_isThumbnailLoading && widget.videoPath != null)
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : const Color(0xFF00FF88).withValues(alpha: 0.2),
              size: 50,
            ),
            if (!_isInitialized && !_isThumbnailLoading && widget.videoPath != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      'فشل تحميل الفيديو',
                      style: TextStyle(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                    if (widget.onRefresh != null)
                      TextButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF00FF88)),
                        label: const Text(
                          'تحديث الرابط',
                          style: TextStyle(color: Color(0xFF00FF88), fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 🎛️ طبقة التحكمات الكاملة
  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // تظليل خفيف
        if (!_isPlaying || _showControls)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

        // 📤 أزرار المشاركة والتحميل (أعلى اليمين)
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOverlayButton(
                icon: Icons.share_rounded,
                onTap: _shareVideo,
                tooltip: 'مشاركة',
              ),
              const SizedBox(width: 6),
              _buildOverlayButton(
                icon: Icons.fullscreen_rounded,
                onTap: () {
                  if (widget.videoPath != null) {
                    Get.to(() => VideoFullScreenViewer(
                      videoUrl: widget.videoPath!,
                      isLocal: widget.isLocal,
                    ), transition: Transition.zoom);
                  }
                },
                tooltip: 'شاشة كاملة',
              ),
              const SizedBox(width: 6),
              _buildOverlayButton(
                icon: _isSaving
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
                onTap: _isSaving ? null : _saveVideo,
                tooltip: 'تحميل',
              ),
            ],
          ),
        ),

        // ▶️ زر التشغيل/الإيقاف (المنتصف)
        if (!_isPlaying || _showControls)
          Center(
            child: _isBuffering
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
          ),

        // 🎚️ شريط التقدم + الوقت (الأسفل)
        if (_isInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
      ],
    );
  }

  /// 🎚️ شريط التحكم السفلي (Seekbar + وقت)
  Widget _buildBottomBar() {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFF00FF88),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: const Color(0xFF00FF88),
              overlayColor: const Color(0xFF00FF88).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).toInt(),
                );
                _controller!.seekTo(newPosition);
              },
              onChangeStart: (_) {
                // إيقاف إخفاء التحكمات أثناء السحب
                _showControls = true;
              },
            ),
          ),

          // الوقت
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                // 🔊 أيقونة الصوت
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller!
                          .setVolume(_controller!.value.volume > 0 ? 0.0 : 1.0);
                    });
                  },
                  child: Icon(
                    _controller!.value.volume > 0
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// زر شفاف فوق الفيديو
  Widget _buildOverlayButton({
    required IconData icon,
    VoidCallback? onTap,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //                  الأحداث
  // ═══════════════════════════════════════════

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
        _showControls = true;
      } else {
        _controller!.play();
        _isPlaying = true;
        // إخفاء التحكمات بعد ثانيتين من التشغيل
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isPlaying) {
            setState(() => _showControls = false);
            _controlsFadeController.forward();
          }
        });
      }
    });
  }

  void _onVideoTap() {
    if (widget.videoPath == null) return;
    
    if (!_isInitialized) {
      _initializeVideo();
      return;
    }

    _togglePlay();
  }

  /// 📤 مشاركة الفيديو
  Future<void> _shareVideo() async {
    try {
      if (widget.videoPath == null) return;

      if (widget.isLocal) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(widget.videoPath!)],
            text: 'فيديو من صانع المحتوى الذكي 🎬',
          ),
        );
      } else {
        // تحميل مؤقت ثم مشاركة
        setState(() => _isSaving = true);
        final response = await http.get(Uri.parse(widget.videoPath!));
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/shared_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'فيديو من صانع المحتوى الذكي 🎬',
          ),
        );
        setState(() => _isSaving = false);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('❌ Share error: $e');
    }
  }

  /// 💾 حفظ الفيديو
  Future<void> _saveVideo() async {
    try {
      if (widget.videoPath == null) return;
      setState(() => _isSaving = true);

      String finalPath = widget.videoPath!;
      
      // إذا كان رابط شبكة، نحمله أولاً
      if (!widget.isLocal) {
        final response = await http.get(Uri.parse(widget.videoPath!));
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        finalPath = file.path;
      }

      // 💾 الحفظ الفعلي في الاستوديو (Gallery)
      await Gal.putVideo(finalPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الفيديو في الاستوديو بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() => _isSaving = false);
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('❌ Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل حفظ الفيديو: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
