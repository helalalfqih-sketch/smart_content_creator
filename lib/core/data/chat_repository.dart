import 'package:get/get.dart';
import '../../services/db_service.dart';
import '../models/chat_message.dart'; // Using the ChatMessage from core models
import 'dart:io';
import '../../controllers/auth_controller.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:convert';
import '../../ai/core/agent_models.dart';

class ChatRepository {
  // 1. الوصول لقاعدة البيانات (تم حقنها مسبقاً)
  final DBService _db = Get.find<DBService>();

  // 2. قائمة الرسائل (Reactive State)
  // هذه القائمة هي "مصدر الحقيقة" للواجهة
  final RxList<ChatMessage> _history = <ChatMessage>[].obs;

  // Getter لحماية القائمة من التعديل المباشر من الخارج (محمي بـ RxList للسماح بالاستماع)
  RxList<ChatMessage> get history => _history;

  /// ✅ إضافة رسالة جديدة وحفظها فوراً
  Future<void> addMessage(ChatMessage msg, {int? sessionId}) async {
    // 1. التحديث الفوري للواجهة (Optimistic UI)
    _history.add(msg);

    // 2. الحفظ في الخلفية (Fire & Forget)
    try {
      // نستخدم logChatMessage الموجود في DBService
      // بما أن ChatMessage يحتوي على دور (role) ومحتوى (content)
      // سنقسم الرسالة حسب الدور إذا لزم الأمر أو نحفظها كما هي
      // ملاحظة: logChatMessage في DBService مصمم لحفظ (userMessage, aiResponse) معاً
      // ولكن يمكن استخدامه لحفظ رسائل منفردة عن طريق ترك أحدهما فارغاً أو تعديله

      final auth = Get.find<AuthController>();
      final userId = auth.user?['id']?.toString();
      final firebaseUid = auth.firebaseUid;

      // 🧠 تجهيز بيانات الـ metadata (الأزرار والتوصيات)
      String? metaData;
      if (msg.actions != null ||
          msg.recommendations != null ||
          msg.videoThumbnail != null ||
          msg.agentResult != null ||
          msg.productContext != null) {
        metaData = jsonEncode({
          if (msg.actions != null) 'actions': msg.actions,
          if (msg.recommendations != null)
            'recommendations': msg.recommendations,
          if (msg.videoThumbnail != null) 'video_thumbnail': msg.videoThumbnail,
          if (msg.videoAuthor != null) 'video_author': msg.videoAuthor,
          if (msg.agentResult != null)
            'agent_result': msg.agentResult!.toJson(),
          if (msg.productContext != null) 'product_context': msg.productContext,
        });
      }

      if (msg.role == 'user') {
        await _db.logChatMessage(
          'gemini',
          msg.content,
          '',
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: msg.mediaPath,
          userId: userId,
          firebaseUid: firebaseUid,
          metaData: metaData,
          productContext: msg.productContext,
        );
      } else {
        await _db.logChatMessage(
          'gemini',
          '',
          msg.content,
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: msg.mediaPath,
          userId: userId,
          firebaseUid: firebaseUid,
          metaData: metaData,
          productContext: msg.productContext,
        );
      }
    } catch (e) {
      debugPrint("❌ ChatRepo Error: $e");
    }
  }

  /// 🔄 تحميل جلسة سابقة
  Future<void> loadSession(int sessionId) async {
    try {
      _history.clear(); // 🧹 Clear BEFORE loading to avoid duplicates/bleeding
      final localMsgs = await _db.getRecords('chat_history', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'created_at ASC');

      final List<ChatMessage> converted = localMsgs.expand((m) {
        final List<ChatMessage> messages = [];
        final userText = m['user_message'] as String? ?? '';
        final aiText = m['ai_response'] as String? ?? '';
        final mediaPath = m['media_path'] as String?;
        final msgType = m['message_type'] ?? 'text';

        // 🧠 استعادة البيانات الإضافية (الأزرار والتوصيات) من meta_data
        List<Map<String, dynamic>>? extractedActions;
        List<Map<String, dynamic>>? extractedRecs;
        String? thumb;
        String? author;
        AgentResult? extractedAgentResult;
        String? extractedProductContext = m['product_context'] as String?;

        final rawMeta = m['meta_data'] as String?;
        if (rawMeta != null && rawMeta.isNotEmpty) {
          try {
            final Map<String, dynamic> meta = jsonDecode(rawMeta);

            if (meta['actions'] != null && meta['actions'] is List) {
              extractedActions = (meta['actions'] as List).map((item) {
                return Map<String, dynamic>.from(item as Map);
              }).toList();
            }

            if (meta['recommendations'] != null &&
                meta['recommendations'] is List) {
              extractedRecs = (meta['recommendations'] as List).map((item) {
                return Map<String, dynamic>.from(item as Map);
              }).toList();
            }

            thumb = meta['video_thumbnail'];
            author = meta['video_author'];

            if (meta['agent_result'] != null) {
              extractedAgentResult = AgentResult.fromJson(
                  Map<String, dynamic>.from(meta['agent_result']));
            }

            // Fallback to metadata if column is somehow missing
            extractedProductContext ??= meta['product_context'];
          } catch (e) {
            debugPrint("⚠️ Metadata parse error in session $sessionId: $e");
          }
        }

        // 1. User Message Piece
        // 📸 Fix: Load user message if it has text OR if it has media (without AI response in same row)
        if (userText.isNotEmpty || (mediaPath != null && aiText.isEmpty)) {
          messages.add(ChatMessage(
            id: "${m['id']}_u",
            role: 'user',
            content: userText,
            // 🎬 Logic: If media exists, it belongs to the user input in this row
            type: mediaPath != null
                ? (msgType == 'video' ? 'video' : 'image')
                : 'text',
            mediaPath: mediaPath,
            image: mediaPath != null ? File(mediaPath) : null,
            videoUrl: msgType == 'video' ? mediaPath : null,
            isNew: false,
            productContext: extractedProductContext,
          ));
        }

        // 2. Assistant Message Piece
        if (aiText.isNotEmpty) {
          // If it started with user text, this is a response row, usually text unless it's a specific generation
          final effectiveType =
              userText.isNotEmpty && msgType == 'text' ? 'text' : msgType;

          messages.add(ChatMessage(
            id: "${m['id']}_a",
            role: 'assistant',
            content: aiText,
            type: effectiveType,
            mediaPath: userText.isEmpty ? mediaPath : null,
            image: userText.isEmpty &&
                    mediaPath != null &&
                    (msgType == 'image' || msgType == 'generated_image')
                ? File(mediaPath)
                : null,
            videoUrl: (userText.isEmpty || msgType == 'video') &&
                    (msgType == 'video' || msgType == 'generated_video')
                ? (mediaPath ?? m['video_url'])
                : null,
            actions: extractedActions,
            recommendations: extractedRecs,
            videoThumbnail: thumb,
            videoAuthor: author,
            isNew: false,
            agentResult: extractedAgentResult,
            productContext: extractedProductContext,
          ));
        }
        return messages;
      }).toList();

      _history.assignAll(converted); // 🚀 Atomic update
      debugPrint(
          "✅ Session $sessionId loaded with ${_history.length} messages (Actions preserved).");
    } catch (e) {
      debugPrint("⚠️ Error loading session: $e");
    }
  }

  /// 🧹 تنظيف الذاكرة (عند بدء دردشة جديدة)
  void clear() {
    _history.clear();
  }

  /// 🔍 استرجاع سياق (Context) سريع
  /// مفيد لـ Gemini لمعرفة آخر ما تحدثنا عنه
  String getLastTopic() {
    if (_history.isEmpty) return "";
    // نأخذ آخر 5 رسائل فقط لبناء السياق
    return _history.reversed.take(5).map((m) => m.content).join("\n");
  }
}
