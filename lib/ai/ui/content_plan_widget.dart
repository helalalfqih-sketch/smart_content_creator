import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/snackbar_utils.dart';
import '../core/agent_models.dart';

class ContentPlanWidget extends StatelessWidget {
  final ContentPlanData data;
  final List<SuggestedAction>? actions;

  const ContentPlanWidget({
    super.key,
    required this.data,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.audience != null) _buildSection("🎯 الجمهور المستهدف", data.audience!),
                
                _buildHooksSection(),
                
                const SizedBox(height: 16),
                _buildSection("✍️ نص الإعلان (Ad Copy)", data.adCopy, showCopy: true),

                if (data.videoScript != null) ...[
                  const SizedBox(height: 16),
                  _buildSection("🎬 سيناريو الفيديو", data.videoScript!, showCopy: true),
                ],

                if (data.visualPrompt != null) ...[
                  const SizedBox(height: 16),
                  _buildSection("🎨 وصف التصوير (Visual Prompt)", data.visualPrompt!, isItalic: true, showCopy: true),
                ],

                if (data.seoTags != null) ...[
                  const SizedBox(height: 16),
                  _buildSection("🏷️ الهاشتاجات المقترحة", data.seoTags!),
                ],
              ],
            ),
          ),
          
          if (actions != null && actions!.isNotEmpty) _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.2),
            Colors.purple.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isItalic = false, bool showCopy = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showCopy)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.blue),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  SnackBarUtils.showSmartSnackBar(
                    title: "تم النسخ",
                    message: "تم نسخ النص إلى الحافظة ✨",
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.5,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHooksSection() {
    if (data.hooks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "🪝 العناوين الجذابة (Hooks)",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...data.hooks.map((hook) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📍 ", style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  hook,
                  style: const TextStyle(color: Colors.amber, fontSize: 15),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions!.map((action) => _buildActionButton(context, action)).toList(),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SuggestedAction action) {
    return ElevatedButton(
      onPressed: () {
        // Here you would typically trigger the action via your controller
        // For now we'll assume the parent handles this or we use a global event bus
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(action.label),
    );
  }
}
