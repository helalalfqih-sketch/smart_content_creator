

/// 🎬 نوع المشهد في الجدول الزمني
enum SceneType {
  cinematic,    // فيديو مولد بـ AI (Kling/Runway)
  staticImage,  // صورة ثابتة مع حركة كاميرا
  textOverlay,  // مشهد نصي فقط
  transition    // انتقال بين المشاهد
}

/// 🎞️ نموذج المشهد الواحد
class SceneModel {
  final String id;
  final SceneType type;
  String visualUrl;           // رابط الفيديو أو الصورة (قابل للتعديل)
  final String? audioUrl;     // رابط التعليق الصوتي (Voiceover)
  final String? subtitle;     // النص الذي يظهر على الشاشة
  final double duration;      // مدة المشهد بالثواني
  final String visualPrompt;  // الـ Prompt الذي أنتج هذا المشهد (لإعادة التوليد)
  final Map<String, dynamic> remotionProps; // خصائص خاصة بمحرك Remotion

  SceneModel({
    required this.id,
    required this.type,
    required this.visualUrl,
    this.audioUrl,
    this.subtitle,
    required this.duration,
    required this.visualPrompt,
    this.remotionProps = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'visualUrl': visualUrl,
    'audioUrl': audioUrl,
    'subtitle': subtitle,
    'duration': duration,
    'visualPrompt': visualPrompt,
    'remotionProps': remotionProps,
  };

  factory SceneModel.fromMap(Map<String, dynamic> map) {
    return SceneModel(
      id: map['id'] ?? '',
      type: SceneType.values.firstWhere((e) => e.name == map['type'], orElse: () => SceneType.cinematic),
      visualUrl: map['visualUrl'] ?? '',
      audioUrl: map['audioUrl'],
      subtitle: map['subtitle'],
      duration: (map['duration'] ?? 5.0).toDouble(),
      visualPrompt: map['visualPrompt'] ?? '',
      remotionProps: map['remotionProps'] ?? {},
    );
  }
}

/// 📽️ نموذج مشروع الفيديو المتكامل
class VideoProject {
  final String id;
  final String title;
  final String prompt;
  final List<SceneModel> scenes;
  final String? backgroundMusicUrl;
  final Map<String, dynamic> metadata;

  VideoProject({
    required this.id,
    required this.title,
    required this.prompt,
    required this.scenes,
    this.backgroundMusicUrl,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'scenes': scenes.map((s) => s.toMap()).toList(),
    'backgroundMusicUrl': backgroundMusicUrl,
    'metadata': metadata,
  };

  factory VideoProject.fromJson(Map<String, dynamic> json) {
    return VideoProject(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      prompt: json['prompt'] ?? '',
      scenes: (json['scenes'] as List?)?.map((s) => SceneModel.fromMap(s)).toList() ?? [],
      backgroundMusicUrl: json['backgroundMusicUrl'],
      metadata: json['metadata'] ?? {},
    );
  }
}
