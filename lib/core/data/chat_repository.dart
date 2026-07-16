import 'package:get/get.dart';
import '../../services/db_service.dart';
import '../models/chat_message.dart'; // Using the ChatMessage from core models
import 'dart:io';
import '../../controllers/auth_controller.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:convert';
import '../../ai/core/agent_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ChatRepository {
  // 1. الوصول لقاعدة البيانات (تم حقنها مسبقاً)
  final DBService _db = Get.find<DBService>();

  // 2. قائمة الرسائل (Reactive State)
  // هذه القائمة هي "مصدر الحقيقة" للواجهة
  final RxList<ChatMessage> _history = <ChatMessage>[].obs;

  // Getter لحماية القائمة من التعديل المباشر من الخارج (محمي بـ RxList للسماح بالاستماع)
  RxList<ChatMessage> get history => _history;

  /// ✅ إضافة رسالة جديدة وحفظها فوراً (تعيد المعرف الرقمي من قاعدة البيانات)
  Future<int?> addMessage(ChatMessage msg, {int? sessionId}) async {
    // 1. التحديث الفوري للواجهة (Optimistic UI)
    _history.add(msg);
    int? dbId;

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

      String? savedPath = msg.mediaPath;
      if (msg.role == 'user' && msg.mediaPath != null) {
        try {
          final file = File(msg.mediaPath!);
          if (await file.exists()) {
            final appDir = await getApplicationDocumentsDirectory();
            final chatMediaDir = Directory('${appDir.path}/chat_media');
            if (!await chatMediaDir.exists()) {
              await chatMediaDir.create(recursive: true);
            }
            final fileName = p.basename(file.path);
            final newFile = await file.copy('${chatMediaDir.path}/$fileName');
            savedPath = newFile.path;
            debugPrint("📸 Persisted user image to: $savedPath");
          }
        } catch (e) {
          debugPrint("⚠️ Failed to persist user image: $e");
        }
      }

      if (msg.role == 'user') {
        dbId = await _db.logChatMessage(
          msg.provider ?? 'gemini',
          msg.content,
          '',
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: savedPath,
          videoUrl: msg.videoUrl,
          state: msg.state.name,
          userId: userId,
          firebaseUid: firebaseUid,
          metaData: metaData,
          productContext: msg.productContext,
        );
      } else {
        dbId = await _db.logChatMessage(
          msg.provider ?? 'gemini',
          '',
          msg.content,
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: msg.mediaPath,
          videoUrl: msg.videoUrl,
          state: msg.state.name,
          userId: userId,
          firebaseUid: firebaseUid,
          metaData: metaData,
          productContext: msg.productContext,
        );
      }
      
      // 3. تحديث الهوية في الذاكرة بعد الحفظ بنجاح
      if (dbId != -1) {
        int index = _history.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          final savedMsg = msg.copyWith(
            id: "${dbId}_${msg.role == 'user' ? 'u' : 'a'}",
            mediaPath: savedPath,
            image: savedPath != null ? File(savedPath) : msg.image,
          );
          _history[index] = savedMsg;
          _history.refresh();
        }
      }

      return dbId;
    } catch (e) {
      debugPrint("❌ ChatRepo Error: $e");
      return null;
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
          final String? finalVideoUrl = m['video_url'] ?? mediaPath;

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
            videoUrl: msgType == 'video' ? finalVideoUrl : null,
            state: MessageState.values.firstWhere(
                (e) => e.name == m['state'],
                orElse: () => MessageState.completed),
            isNew: false,
            productContext: extractedProductContext,
            provider: m['provider'] as String?,
          ));
        }

        // 2. Assistant Message Piece
        if (aiText.isNotEmpty) {
          // If it started with user text, this is a response row, usually text unless it's a specific generation
          final effectiveType =
              userText.isNotEmpty && msgType == 'text' ? 'text' : msgType;

          // 🎬 Robust Video Link Extraction
          final isVideo = effectiveType == 'video' || effectiveType == 'generated_video';
          final String? rawVideoUrl = m['video_url'];
          final String? finalVideoUrl = (rawVideoUrl != null && rawVideoUrl.toString().isNotEmpty) 
              ? rawVideoUrl.toString() 
              : mediaPath;

          if (isVideo) {
            debugPrint("🎬 DB VIDEO DEBUG (Session $sessionId): ID=${m['id']}, type=$effectiveType, url=$finalVideoUrl, media=$mediaPath");
          }

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
            videoUrl: isVideo ? finalVideoUrl : null,
            state: MessageState.values.firstWhere(
                (e) => e.name == m['state'],
                orElse: () => MessageState.completed),
            actions: extractedActions,
            recommendations: extractedRecs,
            videoThumbnail: thumb,
            videoAuthor: author,
            isNew: false,
            agentResult: extractedAgentResult,
            productContext: extractedProductContext,
            provider: m['provider'] as String?,
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

  /// 🔄 تحديث رسالة موجودة (في الذاكرة وقاعدة البيانات)
  Future<void> updateMessage(String messageId, ChatMessage updatedMsg, {int? dbId}) async {
    // 1. التحديث في الذاكرة
    int index = _history.indexWhere((m) => m.id == messageId);
    
    // 🕵️ Fallback: إذا لم نجد الهوية المؤقتة، نبحث بالهوية الدائمة (الرقمية) من قاعدة البيانات
    if (index == -1 && dbId != null) {
      index = _history.indexWhere((m) => m.id == "${dbId}_a" || m.id == "${dbId}_u");
    }

    if (index != -1) {
      _history[index] = updatedMsg;
      _history.refresh(); // 🔥 Force GetX to notify all listeners
      debugPrint("✅ ChatRepo: Message $messageId (dbId: $dbId) updated in memory at index $index");
    } else {
      debugPrint("⚠️ ChatRepo: Could not find message $messageId or dbId $dbId to update.");
      // Fallback: If not found by ID, maybe it's the last assistant message?
      if (_history.isNotEmpty && _history.last.role == 'assistant') {
         _history[_history.length - 1] = updatedMsg;
         _history.refresh();
         debugPrint("🔄 ChatRepo: Fallback applied to last assistant message.");
      }
    }

    // 2. التحديث في قاعدة البيانات (اختياري إذا توفر dbId)
    if (dbId != null) {
      try {
        String? metaData;
        if (updatedMsg.actions != null || updatedMsg.videoThumbnail != null || updatedMsg.agentResult != null) {
          metaData = jsonEncode({
            if (updatedMsg.actions != null) 'actions': updatedMsg.actions,
            if (updatedMsg.videoThumbnail != null) 'video_thumbnail': updatedMsg.videoThumbnail,
            if (updatedMsg.agentResult != null) 'agent_result': updatedMsg.agentResult!.toJson(),
          });
        }

        await _db.updateRecord('chat_history', {
          'ai_response': updatedMsg.role == 'assistant' ? updatedMsg.content : '',
          'user_message': updatedMsg.role == 'user' ? updatedMsg.content : '',
          'video_url': updatedMsg.videoUrl,
          'state': updatedMsg.state.name,
          'meta_data': metaData,
          'product_context': updatedMsg.productContext,
          'provider': updatedMsg.provider,
        }, where: 'id = ?', whereArgs: [dbId]);
      } catch (e) {
        debugPrint("❌ ChatRepo Update Error: $e");
      }
    }
  }
}
