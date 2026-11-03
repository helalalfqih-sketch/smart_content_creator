import 'dart:io';
import '../../core/models/chat_message.dart';

/// Resolve from the clicked message's turn, never global/latest upload state.
List<File> skuImagesForMessage(List<ChatMessage> history, String messageId) {
  final anchor = history.indexWhere((message) => message.id == messageId);
  if (anchor < 0) return const [];
  for (var i = anchor; i >= 0; i--) {
    final message = history[i];
    final files = <String, File>{};
    for (final file in message.images ?? <File>[]) {
      files[file.path] = file;
    }
    if (message.image != null) files[message.image!.path] = message.image!;
    if (files.isNotEmpty) return List.unmodifiable(files.values);
    // A newer turn or a remote-only photo must not borrow an unrelated old image.
    if (message.role == 'user' || message.hasImages) return const [];
  }
  return const [];
}
