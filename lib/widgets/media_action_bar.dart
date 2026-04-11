import 'package:flutter/material.dart';

/// 🎬 Media Action Bar Widget
/// Displays contextual action buttons for generated media (images, videos, audio)
/// Used in chat bubbles to provide quick actions like "Convert to Video", "Add Music", etc.
class MediaActionBar extends StatelessWidget {
  final List<MediaAction> actions;
  final Function(MediaAction) onAction;
  final bool isCompact;

  const MediaActionBar({
    super.key,
    required this.actions,
    required this.onAction,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isCompact) {
      return _buildCompactBar(context, isDark);
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        children: actions.map((action) => _buildActionButton(context, action, isDark)).toList(),
      ),
    );
  }

  Widget _buildCompactBar(BuildContext context, bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildActionButton(context, actions[index], isDark),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, MediaAction action, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.isEnabled ? () => onAction(action) : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: action.isEnabled
                ? LinearGradient(
                    colors: action.gradientColors ?? [
                      action.color.withValues(alpha: 0.2),
                      action.color.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            color: action.isEnabled ? null : (isDark ? Colors.white10 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: action.isEnabled 
                  ? action.color.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: action.isEnabled
                ? [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action.icon,
                style: TextStyle(
                  fontSize: 16,
                  color: action.isEnabled ? null : Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'IBMPlexSansArabic',
                  color: action.isEnabled
                      ? (isDark ? Colors.white : action.color.withValues(alpha: 0.9))
                      : Colors.grey,
                ),
              ),
              if (action.isLoading) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(action.color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 🎯 Media Action Model
class MediaAction {
  final String id;
  final String icon;
  final String label;
  final Color color;
  final List<Color>? gradientColors;
  final bool isEnabled;
  final bool isLoading;
  final Map<String, dynamic>? payload;

  const MediaAction({
    required this.id,
    required this.icon,
    required this.label,
    this.color = Colors.blue,
    this.gradientColors,
    this.isEnabled = true,
    this.isLoading = false,
    this.payload,
  });

  // Predefined actions for AI Creator Studio
  static MediaAction convertToVideo({bool isLoading = false, String? imagePath}) => MediaAction(
    id: 'convert_to_video',
    icon: '🎥',
    label: 'حوّل إلى فيديو',
    color: Colors.purple,
    gradientColors: [Colors.purple.withValues(alpha: 0.2), Colors.pink.withValues(alpha: 0.1)],
    isLoading: isLoading,
    payload: {'imagePath': imagePath},
  );

  static MediaAction addMusic({bool isLoading = false}) => MediaAction(
    id: 'add_music',
    icon: '🎧',
    label: 'أضف موسيقى',
    color: Colors.orange,
    gradientColors: [Colors.orange.withValues(alpha: 0.2), Colors.amber.withValues(alpha: 0.1)],
    isLoading: isLoading,
  );

  static MediaAction addVoice({bool isLoading = false}) => MediaAction(
    id: 'add_voice',
    icon: '🎤',
    label: 'أضف صوت ',
    color: Colors.teal,
    gradientColors: [Colors.teal.withValues(alpha: 0.2), Colors.cyan.withValues(alpha: 0.1)],
    isLoading: isLoading,
  );

  static MediaAction publishTikTok({bool isEnabled = true}) => MediaAction(
    id: 'publish_tiktok',
    icon: '📱',
    label: 'انشر على TikTok',
    color: Colors.black,
    gradientColors: [Colors.black.withValues(alpha: 0.1), Colors.grey.withValues(alpha: 0.05)],
    isEnabled: isEnabled,
  );

  static MediaAction editWithPrompt({String? imagePath}) => MediaAction(
    id: 'edit_with_prompt',
    icon: '🖍️',
    label: 'عدّل بالوصف',
    color: Colors.blueAccent,
    payload: {'imagePath': imagePath},
  );

  static MediaAction enhanceAudio({String? videoPath}) => MediaAction(
    id: 'enhance_audio',
    icon: '🪄',
    label: 'تحسين الصوت ذكي',
    color: Colors.amber,
    payload: {'path': videoPath},
  );

  static MediaAction changeStyle({String? imagePath}) => MediaAction(
    id: 'change_style',
    icon: '🎨',
    label: 'غيّر الأسلوب',
    color: Colors.deepPurpleAccent,
    payload: {'imagePath': imagePath},
  );

  static MediaAction downloadMedia({Map<String, dynamic>? payload}) => MediaAction(
    id: 'download',
    icon: '⬇️',
    label: 'تحميل',
    color: Colors.green,
    payload: payload,
  );

  static MediaAction shareMedia({Map<String, dynamic>? payload}) => MediaAction(
    id: 'share',
    icon: '📤',
    label: 'مشاركة',
    color: Colors.blue,
    payload: payload,
  );

  static MediaAction regenerate() => const MediaAction(
    id: 'regenerate',
    icon: '🔄',
    label: 'توليد جديد',
    color: Colors.indigo,
  );

  /// Get default actions for generated images
  static List<MediaAction> forGeneratedImage({String? imagePath}) => [
    editWithPrompt(imagePath: imagePath),
    changeStyle(imagePath: imagePath),
    convertToVideo(imagePath: imagePath),
  ];

  /// Get default actions for generated videos
  static List<MediaAction> forGeneratedVideo({String? videoPath}) => [
    publishTikTok(),
    downloadMedia(payload: {'path': videoPath}),
    shareMedia(payload: {'path': videoPath}),
  ];

  /// Get default actions for audio
  static List<MediaAction> forGeneratedAudio({String? audioPath}) => [
    shareMedia(payload: {
      'path': audioPath,
      'text': 'شاهد هذا المقطع الصوتي الجديد من صانع المحتوى الذكي 🎧'
    }),
    downloadMedia(payload: {'path': audioPath}),
  ];
}
