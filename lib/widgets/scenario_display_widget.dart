import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_utils.dart';

class ScenarioDisplayWidget extends StatelessWidget {
  final String content;

  const ScenarioDisplayWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final sections = _parseScenario(content);
    
    if (sections.isEmpty) {
      return Text(content, style: const TextStyle(fontSize: 16));
    }

    // Extract Score if present
    final scoreSection = sections.firstWhere((s) => s['type'] == 'score', orElse: () => {});
    
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Score Header (New Feature 2)
          if (scoreSection.isNotEmpty) _buildScoreCard(context, scoreSection),
          
          // Header
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.colorCreative.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.colorCreative.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_filter_rounded, color: AppTheme.colorCreative),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "دليل التصوير والسيناريو 🎬",
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.colorCreative),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.colorCreative),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    SnackBarUtils.showSmartSnackBar(title: 'تم النسخ', message: "تم نسخ السيناريو ✅", isError: false, durationSeconds: 1);
                  },
                )
              ],
            ),
          ),

          // Scenes & Other Sections
          ...sections.where((s) => s['type'] != 'score').map((section) => _buildSectionCard(context, section)),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, Map<String, String> section) {
    String hook = section['hook'] ?? '0';
    if (hook.contains('/')) hook = hook.split('/')[0];
    final hookNum = double.tryParse(hook.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        // Pink/Red Gradient for Excitement/Hook
        gradient: LinearGradient(colors: [AppTheme.colorExcitement, AppTheme.primary]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppTheme.colorExcitement.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🔥 قوة الجذب (Hook)", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text("$hookNum", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text("/10", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("📱 مناسب لـ", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(section['platform'] ?? 'General', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, Map<String, String> section) {
    if (section['type'] == 'concept') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          "💡 الفكرة: ${section['content']}",
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }
    
    // Voice Guide
    if (section['type'] == 'voice') {
       return Container(
         margin: const EdgeInsets.only(bottom: 12),
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: AppTheme.colorTrust.withValues(alpha: 0.1), // Blue
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: AppTheme.colorTrust.withValues(alpha: 0.3)),
         ),
         child: Row(
           children: [
             CircleAvatar(backgroundColor: AppTheme.colorTrust.withValues(alpha: 0.2), child: const Icon(Icons.mic_rounded, color: AppTheme.colorTrust)),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text("دليل التعليق الصوتي 🎙️", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.colorTrust)),
                   const SizedBox(height: 4),
                   Text("${section['content']}", style: const TextStyle(fontSize: 13)),
                 ],
               ),
             ),
             IconButton(
               icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.colorTrust, size: 32),
               onPressed: () {
                 SnackBarUtils.showSmartSnackBar(
                   title: 'قريباً',
                   message: 'ميزة الاستماع للتوجيه غير متاحة حالياً',
                   isError: false,
                   durationSeconds: 2,
                 );
               },
               tooltip: 'استماع للتوجيه',
             )
           ],
         ),
       );
    }
    
    // Tips
    if (section['type'] == 'tips') {
       return Container(
         margin: const EdgeInsets.only(top: 10),
         padding: const EdgeInsets.all(10),
         decoration: BoxDecoration(
           color: AppTheme.colorOptimism.withValues(alpha: 0.15), // Yellow
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: AppTheme.colorOptimism.withValues(alpha: 0.4)),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Row(children: [Icon(Icons.lightbulb_rounded, size: 16, color: AppTheme.colorFriendly), SizedBox(width:5), Text("نصائح إضافية", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.colorFriendly))]),
             const SizedBox(height: 5),
             Text(section['content']!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
           ],
         ),
       );
    }

    // Scene Card
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scene Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      section['title'] ?? 'مشهد', 
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.timer_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(section['time'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Content Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildRow(Icons.videocam_rounded, "الصورة", section['visual'] ?? '-', AppTheme.colorCreative),
                const Divider(height: 16),
                _buildRow(Icons.mic_rounded, "الصوت", section['audio'] ?? '-', AppTheme.colorTrust),
                if (section['text'] != null && section['text']!.isNotEmpty)
                   ...[const Divider(height: 16), _buildRow(Icons.title_rounded, "على الشاشة", section['text']!, AppTheme.colorFriendly)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ],
    );
  }

  // Updated Parser
  List<Map<String, String>> _parseScenario(String text) {
    final List<Map<String, String>> result = [];
    final lines = text.split('\n');
    
    Map<String, String>? currentScene;
    
    // Simple state machine parsing
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      // Type: Concept
      if (line.contains("تحليل الفكرة") || line.contains("Concept")) {
        if(i+1 < lines.length) {
             result.add({'type': 'concept', 'content': lines[i+1].replaceAll('-', '').trim()});
             i++;
        }
        continue;
      }
      
      // Type: Scene (Heuristic regex)
      if (RegExp(r'^\d+[\.\)].*|مشهد').hasMatch(line) && (line.contains("Hook") || line.contains("المشكلة") || line.contains("CTA") || line.contains("تقديم") || line.contains("الإثبات"))) {
         if (currentScene != null) result.add(currentScene);
         currentScene = {
           'type': 'scene',
           'title': line.replaceAll(RegExp(r'[:\*]'), '').trim(),
           'time': '',
           'visual': '',
           'audio': '',
           'text': '',
         };
         continue;
      }
      
      // Scene details
      if (currentScene != null) {
        if (line.contains("⏱️")) {
          currentScene['time'] = line.split("⏱️")[1].trim();
        } else if (line.contains("🎥")) {
          currentScene['visual'] = line.split("🎥")[1].trim();
        } else if (line.contains("🎙️")) {
          currentScene['audio'] = line.split("🎙️")[1].trim();
        } else if (line.contains("📝")) {
          currentScene['text'] = line.split("📝")[1].trim();
        }
      }
      
      // Type: Voice Guide 
      if (line.contains("دليل الصوت") || line.contains("Voice Over")) {
         if (currentScene != null) { result.add(currentScene); currentScene = null; }
         String content = "";
         if(i+1 < lines.length) content += "${lines[i+1].trim()} ";
         if(i+2 < lines.length && lines[i+2].contains("السرعة")) content += "| ${lines[i+2].trim()}";
         result.add({'type': 'voice', 'content': content.replaceAll('-', '').trim()});
      }
      
       // Type: AI Score
      if (line.contains("تقييم الجودة") || line.contains("AI Score")) {
         if (currentScene != null) { result.add(currentScene); currentScene = null; }
         
         String hook = "0";
         String platform = "General";
         
         // Look ahead a few lines
         for(int j=1; j<=4; j++) {
           if(i+j < lines.length) {
              if (lines[i+j].contains("قوة الجذب")) hook = lines[i+j].split(":")[1].trim();
              if (lines[i+j].contains("المنصة")) platform = lines[i+j].split(":")[1].trim();
           }
         }
         result.add({'type': 'score', 'hook': hook, 'platform': platform});
         break; // Usually end of message
      }

      // Type: Tips
      if (line.contains("نصائح إضافية") || line.contains("3️⃣")) {
         if (currentScene != null) { result.add(currentScene); currentScene = null; }
         result.add({'type': 'tips', 'content': lines.skip(i+1).take(2).join('\n').replaceAll('-', '').trim()});
      }
    }
    
    if (currentScene != null && !result.contains(currentScene)) {
      result.add(currentScene);
    }
    
    return result;
  }
}
