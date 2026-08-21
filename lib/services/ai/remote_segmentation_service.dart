import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../core/services/log_service.dart';

/// ✂️ Remote Segmentation & Background Removal Service
///
/// Communicates EXCLUSIVELY with our backend.
/// The backend owns provider selection (Remove.bg, Stability AI, Edge ML models)
/// and manages all secrets and credentials securely.
class RemoteSegmentationService extends GetxService {
  static RemoteSegmentationService get instance => Get.find<RemoteSegmentationService>();

  static const String _backendEndpoint = 'https://smart-content-creator-api.backend.local/api/media/segmentation';
  static const Duration _timeout = Duration(seconds: 45);

  final RxBool isProcessing = false.obs;

  /// ✂️ Remove background from source image file via backend
  Future<File?> removeBackground(File sourceImage) async {
    try {
      if (!await sourceImage.exists()) return null;
      isProcessing.value = true;
      LogService.info('✂️ [RemoteSegmentationService] Sending image to backend for segmentation...', tag: 'SEGMENTATION');

      final bytes = await sourceImage.readAsBytes();
      final transparentBytes = await removeBackgroundFromBytes(bytes);

      if (transparentBytes != null && transparentBytes.isNotEmpty) {
        final directory = await getTemporaryDirectory();
        final String outputPath = '${directory.path}/transparent_isolated_${DateTime.now().millisecondsSinceEpoch}.png';
        final File outputFile = File(outputPath);
        await outputFile.writeAsBytes(transparentBytes);
        LogService.info('✅ [RemoteSegmentationService] Successfully received transparent PNG: $outputPath', tag: 'SEGMENTATION');
        return outputFile;
      }
    } catch (e) {
      LogService.error('❌ [RemoteSegmentationService] Error: $e', tag: 'SEGMENTATION');
    } finally {
      isProcessing.value = false;
    }
    return null;
  }

  /// ✂️ Remove background from raw image bytes via backend
  Future<Uint8List?> removeBackgroundFromBytes(Uint8List imageBytes) async {
    try {
      isProcessing.value = true;
      final uri = Uri.parse(_backendEndpoint);
      final headers = await _getAuthHeaders();

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'source_image.png',
      ));
      request.fields['format'] = 'png';
      request.fields['mode'] = 'foreground_isolate';

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      } else {
        LogService.error('❌ [RemoteSegmentationService] Backend returned ${response.statusCode}: ${response.body}', tag: 'SEGMENTATION');
      }
    } catch (e) {
      LogService.error('❌ [RemoteSegmentationService] Request exception: $e', tag: 'SEGMENTATION');
    } finally {
      isProcessing.value = false;
    }
    return null;
  }

  /// 🔒 Authenticated headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Accept': 'image/png, application/json',
    };

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    } catch (_) {}

    return headers;
  }
}
