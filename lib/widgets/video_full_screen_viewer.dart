import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class VideoFullScreenViewer extends StatefulWidget {
  final String videoUrl;
  final bool isLocal;

  const VideoFullScreenViewer({
    super.key,
    required this.videoUrl,
    this.isLocal = false,
  });

  @override
  State<VideoFullScreenViewer> createState() => _VideoFullScreenViewerState();
}

class _VideoFullScreenViewerState extends State<VideoFullScreenViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.isLocal) {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    }

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
      _controller.setLooping(true);
    } catch (e) {
      debugPrint("❌ FullScreen Error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveVideo() async {
    try {
      setState(() => _isSaving = true);
      String finalPath = widget.videoUrl;

      if (!widget.isLocal) {
        final response = await http.get(Uri.parse(widget.videoUrl));
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        finalPath = file.path;
      }

      await Gal.putVideo(finalPath);
      Get.snackbar(
        '✅ نجاح',
        'تم حفظ الفيديو في الاستوديو بنجاح!',
        backgroundColor: Colors.green.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        '❌ خطأ',
        'فشل حفظ الفيديو: $e',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 🎥 Video Player
          if (_isInitialized)
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)),
            ),

          // 🔙 Back Button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),

          // 💾 Save Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: _isSaving ? null : _saveVideo,
            ),
          ),

          // ⏯️ Play/Pause Overlay
          if (_isInitialized && !_controller.value.isPlaying)
            IgnorePointer(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 80,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}
