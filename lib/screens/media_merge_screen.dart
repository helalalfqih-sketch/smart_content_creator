import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/media_merge_service.dart';
import '../widgets/modern_video_bubble.dart';

/// 🎬 شاشة دمج المنتج مع الفيديو
/// واجهة تفاعلية لدمج صور المنتجات فوق الفيديوهات
class MediaMergeScreen extends StatefulWidget {
  /// صورة مبدئية (اختياري - تُمرّر من الشات)
  final File? initialImage;

  /// فيديو مبدئي (اختياري)
  final String? initialVideoPath;

  const MediaMergeScreen({
    super.key,
    this.initialImage,
    this.initialVideoPath,
  });

  @override
  State<MediaMergeScreen> createState() => _MediaMergeScreenState();
}

class _MediaMergeScreenState extends State<MediaMergeScreen>
    with SingleTickerProviderStateMixin {
  late final MediaMergeService _mergeService;

  File? _productImage;
  String? _videoPath;
  VideoPlayerController? _previewController;
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // التسجيل المؤقت إذا لم يكن موجوداً
    if (!Get.isRegistered<MediaMergeService>()) {
      Get.put(MediaMergeService());
    }
    _mergeService = Get.find<MediaMergeService>();

    // استخدام الملفات المُمررة
    if (widget.initialImage != null) {
      _productImage = widget.initialImage;
    }
    if (widget.initialVideoPath != null) {
      _videoPath = widget.initialVideoPath;
      _initPreview();
    }
  }

  Future<void> _initPreview() async {
    if (_videoPath == null) return;
    _previewController?.dispose();
    _previewController = VideoPlayerController.file(File(_videoPath!));
    await _previewController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.grey[50],
      appBar: _buildAppBar(isDark),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── الجانب الأيسر: المعاينة ───
                Expanded(
                  flex: 3,
                  child: Container(
                    height: double.infinity,
                    padding: EdgeInsets.all(24.r),
                    child: _buildPreviewArea(isDark),
                  ),
                ),

                // ─── فاصل رفيع ───
                Container(
                  width: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),

                // ─── الجانب الأيمن: أدوات التحكم ───
                SizedBox(
                  width: 380, // عرض ثابت ومريح للأدوات في الشاشات الكبيرة
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: _buildControlPanel(isDark),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // ─── المعاينة ───
                Expanded(child: _buildPreviewArea(isDark)),

                // ─── أدوات التحكم ───
                _buildControlPanel(isDark),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //                        AppBar
  // ═══════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      elevation: 0,
      title: const Text(
        '🎬 دمج المنتج',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'IBMPlexSansArabic',
        ),
      ),
      centerTitle: true,
      actions: [
        Obx(() => _mergeService.isProcessing.value
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF00FF88))),
              )
            : IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  _mergeService.resetSettings();
                  setState(() {
                    _productImage = null;
                    _videoPath = null;
                    _previewController?.dispose();
                    _previewController = null;
                  });
                },
              )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //                    منطقة المعاينة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPreviewArea(bool isDark) {
    return Obx(() {
      // عرض النتيجة النهائية
      if (_mergeService.resultVideoPath.value != null) {
        return _buildResultView(isDark);
      }

      // عرض حالة المعالجة
      if (_mergeService.isProcessing.value) {
        return _buildProcessingView(isDark);
      }

      // عرض مناطق الرفع
      return _buildUploadArea(isDark);
    });
  }

  /// منطقة رفع الملفات
  Widget _buildUploadArea(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── رفع صورة المنتج ───
          Expanded(
            child: GestureDetector(
              onTap: _pickProductImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _productImage != null
                        ? const Color(0xFF00FF88)
                        : (isDark ? Colors.white12 : Colors.grey[300]!),
                    width: _productImage != null ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_productImage != null)
                      BoxShadow(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                  ],
                ),
                child: _productImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              _productImage!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FF88),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.black, size: 16),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 48,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '📸 اختر صورة المنتج',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'سيتم إزالة الخلفية تلقائياً',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.grey[400],
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ─── رفع الفيديو ───
          Expanded(
            child: GestureDetector(
              onTap: _pickVideo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _videoPath != null
                        ? const Color(0xFF7C4DFF)
                        : (isDark ? Colors.white12 : Colors.grey[300]!),
                    width: _videoPath != null ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_videoPath != null)
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                  ],
                ),
                child: _videoPath != null &&
                        _previewController != null &&
                        _previewController!.value.isInitialized
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: double.infinity,
                              child: VideoPlayer(_previewController!),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C4DFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDuration(
                                    _previewController!.value.duration),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_rounded,
                            size: 48,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '🎥 اختر مقطع الفيديو',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'أفضل نسبة: 9:16 (Reels)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.grey[400],
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض حالة المعالجة
  Widget _buildProcessingView(bool isDark) {
    return Center(
      child: Obx(() => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أنيميشن التحميل
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: _mergeService.progress.value,
                      strokeWidth: 4,
                      color: const Color(0xFF00FF88),
                      backgroundColor:
                          isDark ? Colors.white10 : Colors.grey[200],
                    ),
                  ),
                  Text(
                    '${(_mergeService.progress.value * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // رسالة الحالة
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00FF88),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _mergeService.statusMessage.value,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'قد يستغرق الأمر 1-3 دقائق',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white30 : Colors.grey[400],
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ],
          )),
    );
  }

  /// عرض النتيجة
  Widget _buildResultView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // شارة النجاح
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 18),
                SizedBox(width: 8),
                Text(
                  '✨ تم الدمج بنجاح!',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // مشغّل الفيديو الناتج
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ModernVideoBubble(
                videoPath: _mergeService.resultVideoPath.value,
                isLocal: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //                    لوحة التحكم
  // ═══════════════════════════════════════════════════════════════

  Widget _buildControlPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12122A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── إعدادات سريعة ───
          Obx(() => Column(
                children: [
                  // حجم المنتج
                  _buildSlider(
                    label: '📐 حجم المنتج',
                    value: _mergeService.imageScale.value,
                    min: 0.1,
                    max: 0.7,
                    onChanged: (v) => _mergeService.imageScale.value = v,
                    isDark: isDark,
                  ),

                  // الشفافية
                  _buildSlider(
                    label: '💧 الشفافية',
                    value: _mergeService.opacity.value,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => _mergeService.opacity.value = v,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 4),

                  // خيارات إضافية
                  Row(
                    children: [
                      // إزالة الخلفية
                      Expanded(
                        child: _buildChipOption(
                          label: '🖼️ إزالة الخلفية',
                          isSelected: _mergeService.removeBackground.value,
                          onTap: () => _mergeService.removeBackground.value =
                              !_mergeService.removeBackground.value,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // موضع ذكي
                      Expanded(
                        child: _buildChipOption(
                          label: '🧠 موضع ذكي AI',
                          isSelected: true,
                          onTap: () {},
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              )),

          const SizedBox(height: 12),

          // ─── زر الدمج ───
          Obx(() => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canMerge() && !_mergeService.isProcessing.value
                      ? _startMerge
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canMerge()
                        ? const Color(0xFF00FF88)
                        : (isDark ? Colors.white10 : Colors.grey[300]),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: _canMerge() ? 4 : 0,
                    shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  ),
                  child: _mergeService.isProcessing.value
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black)),
                            SizedBox(width: 10),
                            Text('جاري الدمج...',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'IBMPlexSansArabic')),
                          ],
                        )
                      : Text(
                          _canMerge()
                              ? '🚀 ابدأ الدمج'
                              : '📎 حمّل الصورة والفيديو أولاً',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: const Color(0xFF00FF88),
                inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200],
                thumbColor: const Color(0xFF00FF88),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 35,
            child: Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF88).withValues(alpha: 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FF88).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? const Color(0xFF00FF88)
                : (isDark ? Colors.white54 : Colors.grey[500]),
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //                       الأحداث
  // ═══════════════════════════════════════════════════════════════

  bool _canMerge() => _productImage != null && _videoPath != null;

  Future<void> _pickProductImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _productImage = File(picked.path));
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      _videoPath = picked.path;
      await _initPreview();
      setState(() {});
    }
  }

  Future<void> _startMerge() async {
    if (!_canMerge()) return;

    final result = await _mergeService.mergeImageWithVideo(
      productImage: _productImage!,
      videoPath: _videoPath!,
      smartPosition: true,
      aspectRatio: '9:16',
    );

    if (result != null) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }
}
