import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../core/services/log_service.dart';
import '../utils/logger.dart';

/// ✈️ Telegram Service
/// Handles communication with the Telegram Bot API for publishing content.
class TelegramService extends GetxService {
  final SettingsController _settings = Get.find<SettingsController>();

  String? get _botToken => _settings.getApiKey(ProviderType.telegram);
  String? get _chatId => _settings.providerSecrets[ProviderType.telegram];

  bool get isConfigured =>
      _botToken != null && _botToken!.isNotEmpty && _chatId != null && _chatId!.isNotEmpty;

  /// 📝 Send a text message to the configured Telegram chat/channel
  Future<bool> sendMessage(String text) async {
    if (!isConfigured) {
      AppLogger.error("Telegram is not configured. Missing Token or Chat ID.");
      return false;
    }

    // 🕵️ سجل آمن للتحقق من المعرف
    final String safeId = _chatId ?? "";
    final maskedId = safeId.length > 4 
        ? "${safeId.substring(0, 3)}...${safeId.substring(safeId.length - 2)}" 
        : safeId;
    AppLogger.info("✈️ Attempting to send message to Chat ID: '$maskedId' (Length: ${safeId.length})");

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
    
    try {
      final response = await http.post(
        url,
        body: {
          'chat_id': _chatId,
          'text': text,
          'parse_mode': 'HTML',
        },
      );

      if (response.statusCode == 200) {
        AppLogger.info("✅ Telegram Publishing: Success");
        return true;
      } else {
        AppLogger.error("❌ Telegram Publishing: Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      LogService.error("Telegram Service Error: $e");
      return false;
    }
  }

  /// 🖼️ Send a photo with an optional caption
  Future<bool> sendPhoto(File imageFile, {String? caption}) async {
    if (!isConfigured) {
      AppLogger.error("Telegram is not configured.");
      return false;
    }

    final String safeId = _chatId ?? "";
    final maskedId = safeId.length > 4 
        ? "${safeId.substring(0, 3)}...${safeId.substring(safeId.length - 2)}" 
        : safeId;
    AppLogger.info("✈️ Attempting to send photo to Chat ID: '$maskedId' (Length: ${safeId.length})");

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendPhoto');
    
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = _chatId!
        ..fields['parse_mode'] = 'HTML'
        ..files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
      
      if (caption != null) {
        request.fields['caption'] = caption;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        AppLogger.info("✅ Photo sent to Telegram successfully!");
        return true;
      } else {
        AppLogger.error("❌ Failed to send photo to Telegram: ${response.body}");
        return false;
      }
    } catch (e) {
      LogService.error("Telegram Service Photo Error: $e");
      return false;
    }
  }

  /// 🎬 Send a video with an optional caption
  Future<bool> sendVideo(File videoFile, {String? caption}) async {
    if (!isConfigured) return false;

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendVideo');
    
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = _chatId!
        ..fields['parse_mode'] = 'HTML'
        ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));
      
      if (caption != null) {
        request.fields['caption'] = caption;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      LogService.error("Telegram Service Video Error: $e");
      return false;
    }
  }
}
