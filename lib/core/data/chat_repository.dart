import 'package:get/get.dart';
import '../../services/db_service.dart';
import '../models/chat_message.dart';
import '../models/chat_attachment.dart';
import 'dart:io';
import '../../controllers/auth_controller.dart';
import 'package:flutter/foundation.dart';
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

  /// 💾 حفظ وتكرار الملفات محلياً في مجلد مخصص للجلسات لضمان بقائها بعد إغلاق التطبيق
  Future<List<ChatAttachment>> _persistAttachmentsLocally(List<ChatAttachment> attachments) async {
    if (attachments.isEmpty) return attachments;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chatMediaDir = Directory('${appDir.path}/chat_media');
      if (!await chatMediaDir.exists()) {
        await chatMediaDir.create(recursive: true);
      }

      final List<ChatAttachment> persisted = [];
      for (final att in attachments) {
        if (att.localPath != null && att.localPath!.isNotEmpty) {
          final file = File(att.localPath!);
          // إذا كان الملف موجوداً ولم يتم نسخه بعد لمجلد chat_media
          if (await file.exists() && !att.localPath!.startsWith(chatMediaDir.path)) {
            final fileName = "${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}";
            final newPath = '${chatMediaDir.path}/$fileName';
            final newFile = await file.copy(newPath);
            persisted.add(att.copyWith(localPath: newFile.path));
            debugPrint("📸 Persisted attachment (${att.type.name}) to: ${newFile.path}");
            continue;
          }
        }
        persisted.add(att);
      }
      return persisted;
    } catch (e) {
      debugPrint("⚠️ Failed to persist attachments locally: $e");
      return attachments;
    }
  }

  /// ✅ إضافة رسالة جديدة وحفظها فوراً (تعيد المعرف الرقمي من قاعدة البيانات)
  Future<int?> addMessage(ChatMessage msg, {int? sessionId}) async {
    // 1. التحديث الفوري للواجهة (Optimistic UI)
    _history.add(msg);
    int? dbId;

    // 2. الحفظ في الخلفية (Fire & Forget)
    try {
      final auth = Get.find<AuthController>();
      final userId = auth.user?['id']?.toString();
      final firebaseUid = auth.firebaseUid;

      // حفظ المرفقات محلياً
      final persistedAttachments = await _persistAttachmentsLocally(msg.attachments);

      // 🧠 تجهيز بيانات الـ metadata (المرفقات الموحدة + الأزرار والتوصيات)
      String? metaData;
      metaData = jsonEncode({
        if (persistedAttachments.isNotEmpty)
          'attachments': persistedAttachments.map((a) => a.toJson()).toList(),
        if (msg.actions != null) 'actions': msg.actions,
        if (msg.recommendations != null)
          'recommendations': msg.recommendations,
        if (msg.videoThumbnail != null) 'video_thumbnail': msg.videoThumbnail,
        if (msg.videoAuthor != null) 'video_author': msg.videoAuthor,
        if (msg.agentResult != null)
          'agent_result': msg.agentResult!.toJson(),
        if (msg.productContext != null) 'product_context': msg.productContext,
      });

      final firstAtt = persistedAttachments.firstOrNull;
      final savedMediaPath = firstAtt?.localPath ?? firstAtt?.remoteUrl ?? msg.mediaPath;
      final firstVid = persistedAttachments.where((a) => a.isVideo).firstOrNull;
      final savedVideoUrl = firstVid?.remoteUrl ?? firstVid?.localPath ?? msg.videoUrl;

      if (msg.role == 'user') {
        dbId = await _db.logChatMessage(
          msg.provider ?? 'manus',
          msg.content,
          '',
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: savedMediaPath,
          videoUrl: savedVideoUrl,
          state: msg.state.name,
          userId: userId,
          firebaseUid: firebaseUid,
          metaData: metaData,
          productContext: msg.productContext,
        );
      } else {
        dbId = await _db.logChatMessage(
          msg.provider ?? 'manus',
          '',
          msg.content,
          sessionId: sessionId,
          messageType: msg.type,
          mediaPath: savedMediaPath,
          videoUrl: savedVideoUrl,
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
            attachments: persistedAttachments,
            mediaPath: savedMediaPath,
            videoUrl: savedVideoUrl,
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
        final videoUrl = m['video_url'] as String?;
        final msgType = m['message_type'] ?? 'text';

        // 🧠 استعادة البيانات الإضافية والمرفقات من meta_data
        List<ChatAttachment> extractedAttachments = [];
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

            if (meta['attachments'] != null && meta['attachments'] is List) {
              extractedAttachments = (meta['attachments'] as List)
                  .map((item) => ChatAttachment.fromJson(Map<String, dynamic>.from(item as Map)))
                  .toList();
            }

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

            extractedProductContext ??= meta['product_context'];
          } catch (e) {
            debugPrint("⚠️ Metadata parse error in session $sessionId: $e");
          }
        }

        // Fallback إذا لم توجد مرفقات في meta_data القديمة
        if (extractedAttachments.isEmpty) {
          if (mediaPath != null && mediaPath.isNotEmpty) {
            final f = File(mediaPath);
            if (f.existsSync()) {
              extractedAttachments.add(ChatAttachment.fromLocalFile(file: f));
            } else {
              extractedAttachments.add(ChatAttachment.fromRemote(url: mediaPath));
            }
          }
          if (videoUrl != null && videoUrl.isNotEmpty) {
            extractedAttachments.add(ChatAttachment.fromRemote(
              url: videoUrl,
              contentType: 'video/mp4',
              thumbnailUrl: thumb,
            ));
          }
        }

        // 1. User Message Piece
        if (userText.isNotEmpty || (extractedAttachments.isNotEmpty && aiText.isEmpty) || (mediaPath != null && aiText.isEmpty)) {
          final String? finalVideoUrl = videoUrl ?? mediaPath;

          messages.add(ChatMessage(
            id: "${m['id']}_u",
            role: 'user',
            content: userText,
            attachments: extractedAttachments,
            type: msgType,
            mediaPath: mediaPath,
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
          final effectiveType =
              userText.isNotEmpty && msgType == 'text' ? 'text' : msgType;

          final isVideo = effectiveType == 'video' || effectiveType == 'generated_video';
          final String? finalVideoUrl = (videoUrl != null && videoUrl.isNotEmpty) 
              ? videoUrl 
              : mediaPath;

          messages.add(ChatMessage(
            id: "${m['id']}_a",
            role: 'assistant',
            content: aiText,
            attachments: extractedAttachments,
            type: effectiveType,
            mediaPath: userText.isEmpty ? mediaPath : null,
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
          "✅ Session $sessionId loaded with ${_history.length} messages.");
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
    
    // 🕵️ Fallback: إذا لم نجد الهوية المؤقتة، نبحث بالهوية الدائمة
    if (index == -1 && dbId != null) {
      index = _history.indexWhere((m) => m.id == "${dbId}_a" || m.id == "${dbId}_u");
    }

    if (index != -1) {
      _history[index] = updatedMsg;
      _history.refresh(); // 🔥 Force GetX to notify all listeners
      debugPrint("✅ ChatRepo: Message $messageId (dbId: $dbId) updated in memory at index $index");
    } else {
      debugPrint("⚠️ ChatRepo: Could not find message $messageId or dbId $dbId to update.");
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
        metaData = jsonEncode({
          if (updatedMsg.attachments.isNotEmpty)
            'attachments': updatedMsg.attachments.map((a) => a.toJson()).toList(),
          if (updatedMsg.actions != null) 'actions': updatedMsg.actions,
          if (updatedMsg.videoThumbnail != null) 'video_thumbnail': updatedMsg.videoThumbnail,
          if (updatedMsg.agentResult != null) 'agent_result': updatedMsg.agentResult!.toJson(),
          if (updatedMsg.productContext != null) 'product_context': updatedMsg.productContext,
        });

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
