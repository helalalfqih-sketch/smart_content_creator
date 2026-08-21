import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'remote_segmentation_service.dart';

/// ✂️ Background Removal Service (Compatibility Adapter)
///
/// Routes all segmentation requests to [RemoteSegmentationService] on the backend,
/// eliminating all heavy local ML Kit native binaries.
class BackgroundRemovalService extends GetxService {
  RemoteSegmentationService get _remoteService => Get.find<RemoteSegmentationService>();

  /// ✂️ Removes background from image and returns transparent PNG file
  Future<File?> removeBackground(File sourceImage, {dio.CancelToken? cancelToken}) async {
    try {
      if (kDebugMode) debugPrint("[✂️ Background Removal]: Routing to RemoteSegmentationService...");
      return await _remoteService.removeBackground(sourceImage);
    } catch (e) {
      if (kDebugMode) debugPrint("[❌ Background Removal Error]: $e");
      return null;
    }
  }
}
