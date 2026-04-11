import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

/// 🎬 مشغّل فيديو حديث داخل فقاعة الشات
/// مستوحى من واجهة Google Gemini
/// يدعم: Seekbar، أزرار مشاركة/تحميل، عرض الوقت
class ModernVideoBubble extends StatefulWidget {
  final String? videoPath;
  final String? thumbnailUrl;
  final bool isLocal;

  const ModernVideoBubble({
    super.key,
    required this.videoPath,
    this.thumbnailUrl,
    this.isLocal = false,
  });

  @override
  State<ModernVideoBubble> createState() => _ModernVideoBubbleState();
}

class _ModernVideoBubbleState extends State<ModernVideoBubble>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isBuffering = false;
  String? _thumbnailPath;
  bool _isThumbnailLoading = true;
  bool _isSaving = false;

  late AnimationController _controlsFadeController;
  late Animation<double> _controlsFade;

  @override
  void initState() {
    super.initState();
    _controlsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controlsFade =
        Tween<double>(begin: 1.0, end: 0.0).animate(_controlsFadeController);

    if (widget.isLocal) {
      _initializeVideo();
    } else {
      _generateThumbnail();
    }
  }

  /// توليد غلاف للفيديو
  Future<void> _generateThumbnail() async {
    try {
      if (widget.thumbnailUrl != null) {
        if (mounted) setState(() => _isThumbnailLoading = false);
        return;
      }

      if (!widget.isLocal) {
        if (mounted) setState(() => _isThumbnailLoading = false);
        return;
      }

      final String? fileName = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath!,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 85,
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = fileName;
          _isThumbnailLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isThumbnailLoading = false);
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (_controller != null) return;
      if (widget.videoPath == null) return;

      if (widget.isLocal) {
        _controller = VideoPlayerController.file(File(widget.videoPath!));
      } else {
        _controller =
            VideoPlayerController.networkUrl(Uri.parse(widget.videoPath!));
      }

      await _controller!.initialize();

      _controller!.addListener(() {
        if (!mounted) return;

        // تحديث حالة التخزين المؤقت
        final isBuffering = _controller!.value.isBuffering;
        if (isBuffering != _isBuffering) {
          setState(() => _isBuffering = isBuffering);
        }

        // إعادة التشغيل من البداية عند الانتهاء
        if (_controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration > Duration.zero) {
          setState(() {
            _isPlaying = false;
            _showControls = true;
            _controlsFadeController.reverse();
            _controller!.seekTo(Duration.zero);
          });
        }

        // تحديث الواجهة للـ seekbar
        if (_isPlaying && mounted) {
          setState(() {});
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isThumbnailLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الفيديو: $e");
      if (mounted) setState(() => _isThumbnailLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controlsFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

  /// المحتوى الرئيسي (فيديو أو غلاف)
  Widget _buildMainContent() {
    if (_isInitialized && _controller != null) {
      return VideoPlayer(_controller!);
    }

    if (widget.thumbnailUrl != null) {
      return Image.network(
        widget.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
      );
    }

    if (_thumbnailPath != null) {
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
        child: Icon(Icons.movie_creation_outlined,
            color: const Color(0xFF00FF88).withValues(alpha: 0.2), size: 50),
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

  void _onVideoTap() {
    if (!_isInitialized) {
      _initializeAndPlay();
      return;
    }

    if (_isPlaying) {
      setState(() => _showControls = !_showControls);
      if (_showControls) {
        // إخفاء تلقائي بعد 3 ثواني
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
    } else {
      _togglePlay();
    }
  }

  void _togglePlay() {
    if (!_isInitialized) {
      _initializeAndPlay();
      return;
    }
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _showControls = true;
      } else {
        _controller!.play();
        // إخفاء تلقائي بعد 3 ثواني
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _initializeAndPlay() async {
    setState(() => _isThumbnailLoading = true);
    await _initializeVideo();
    if (_isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _showControls = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
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

      if (widget.isLocal) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(widget.videoPath!)],
            text: 'حفظ الفيديو',
          ),
        );
      } else {
        final response = await http.get(Uri.parse(widget.videoPath!));
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'حفظ الفيديو',
          ),
        );
      }

      setState(() => _isSaving = false);
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('❌ Save error: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
