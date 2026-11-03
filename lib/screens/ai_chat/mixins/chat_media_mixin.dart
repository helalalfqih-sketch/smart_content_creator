import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart' hide Intent;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/error_handler.dart';
import '../../../ai/chat_smart_agent.dart';
import '../../../ai/core/agent_models.dart';
import '../../../controllers/auth_controller.dart';
import '../../../gallery/gallery_library_screen.dart';
import '../../../gallery/gallery_owner.dart';
import '../../ai_chat_screen.dart';

mixin ChatMediaMixin on State<AiChatScreen> {
  final ImagePicker picker = ImagePicker();
  final ChatSmartAgent agent = Get.find<ChatSmartAgent>();

  List<File> selectedImages = [];
  bool isCompressingImage = false;
  List<File> compressedImages = [];
  double processingProgress = 0.0;
  Timer? progressTimer;
  ProcessedInput? preAnalysisResult;
  File? selectedVideo;
  int _imagePreparation = 0;
  String? _libraryOwner;
  Worker? _libraryAccountWatcher;

  void scrollToBottom({bool force = false});

  String galleryAccountOwner() => currentGalleryOwner();

  bool mediaAccountIsCurrent() {
    if (_libraryOwner == null || _libraryOwner == galleryAccountOwner()) return true;
    clearPickedMedia();
    return false;
  }

  Future<void> pickGalleryLibrary() async {
    if (!mounted || isCompressingImage) return;
    try {
      _libraryAccountWatcher ??= ever(Get.find<AuthController>().rxUser, (_) {
        if (mounted) mediaAccountIsCurrent();
      });
      final selection = await Navigator.of(context).push<GalleryChatSelection>(
        MaterialPageRoute(builder: (_) => const GalleryLibraryScreen()),
      );
      if (!mounted || selection == null) return;
      await attachGallerySelection(selection);
    } catch (_) {
      if (mounted) ErrorHandler.showFileError();
    }
  }

  Future<void> attachGallerySelection(GalleryChatSelection selection) async {
    if (!mounted || selection.owner != galleryAccountOwner()) return;
    _libraryOwner = selection.owner;
    await handlePickedImages(selection.files);
  }

  void clearPickedMedia() {
    _imagePreparation++;
    progressTimer?.cancel();
    _libraryOwner = null;
    if (!mounted) return;
    setState(() {
      selectedImages = [];
      compressedImages = [];
      selectedVideo = null;
      isCompressingImage = false;
      processingProgress = 0;
      preAnalysisResult = null;
    });
  }

  void disposeMedia() {
    _imagePreparation++;
    progressTimer?.cancel();
    _libraryAccountWatcher?.dispose();
  }

  Future<void> pickAnyMediaFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'mp4',
          'mov',
          'mp3',
          'wav',
          'aac'
        ],
      );

      if (result != null) {
        final List<File> pickedFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        for (var file in pickedFiles) {
          final extension =
              p.extension(file.path).toLowerCase().replaceAll('.', '');

          if (['jpg', 'jpeg', 'png'].contains(extension)) {
            handlePickedImages([file]);
          } else if (['mp4', 'mov'].contains(extension)) {
            handlePickedVideo(file);
          } else if (['mp3', 'wav', 'aac'].contains(extension)) {
            handlePickedAudio(file);
          }
        }
      }
    } catch (e) {
      ErrorHandler.showFileError();
    }
  }

  Future<void> handlePickedImages(List<File> images) async {
    if (!mounted || !mediaAccountIsCurrent()) return;
    progressTimer?.cancel();
    setState(() {
      final paths = selectedImages.map((f) => f.path).toSet();
      selectedImages = [...selectedImages, ...images.where((f) => paths.add(f.path))];
      selectedVideo = null;
      compressedImages = [];
      isCompressingImage = true;
      processingProgress = 0.0;
      preAnalysisResult = null;
    });

    startSimulatedProgress();

    await compressImages(selectedImages);
  }

  Future<void> removePickedImage(int index) async {
    if (!mounted || index < 0 || index >= selectedImages.length) return;
    setState(() {
      selectedImages = [...selectedImages]..removeAt(index);
      compressedImages = [];
      preAnalysisResult = null;
      isCompressingImage = selectedImages.isNotEmpty;
    });
    if (selectedImages.isEmpty) {
      clearPickedMedia();
    } else {
      await compressImages(selectedImages);
    }
  }

  void startSimulatedProgress() {
    progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (processingProgress < 0.90) {
          processingProgress += 0.005;
        } else {
          if (processingProgress > 0.95) {
            processingProgress = 0.90;
          } else {
            processingProgress += 0.001;
          }
        }
      });
    });
  }

  void handlePickedVideo(File video) {
    clearPickedMedia();
    if (!mounted) return;
    setState(() {
      selectedVideo = video;
      selectedImages = [];
    });

    // logic moved from screen to mixin if applicable, or kept in UI
    // For now, let's keep the UI bottom sheet in the screen but call this method
  }

  void handlePickedAudio(File audio) {
    clearPickedMedia();
    if (!mounted) return;
    setState(() {
      selectedVideo = audio;
    });
    // This will trigger enhancement flow in the screen or another mixin
  }

  Future<List<File>> prepareImagesForChat(List<File> files) =>
      compute(ImageUtils.batchCompressAndRead, files);

  Future<void> compressImages(List<File> files) async {
    final revision = ++_imagePreparation;
    final snapshot = List<File>.of(files);
    try {
      final compressedList = await prepareImagesForChat(snapshot);
      if (!mounted || revision != _imagePreparation || !mediaAccountIsCurrent()) return;
      setState(() {
        compressedImages = compressedList;
        isCompressingImage = false;
        processingProgress = 1;
      });
    } catch (e) {
      debugPrint("Compression failed: $e");
      if (mounted && revision == _imagePreparation && mediaAccountIsCurrent()) {
        setState(() {
          isCompressingImage = false;
          compressedImages = snapshot;
          processingProgress = 1;
        });
      }
    } finally {
      if (revision == _imagePreparation) progressTimer?.cancel();
    }
  }

  Future<void> pickVideoForAudioEnhance() async {
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      if (mounted) {
        handlePickedVideo(File(video.path));
        // Note: The screen will usually call handleAudioEnhancement right after
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          final List<File> files =
              pickedFiles.map((x) => File(x.path)).toList();
          await handlePickedImages(files);
        }
      } else {
        final XFile? pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          await handlePickedImages([File(pickedFile.path)]);
        }
      }
    } catch (e) {
      ErrorHandler.showFileError();
    }
  }
}
