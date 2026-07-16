
enum ProviderType {
  gemini,      // Google AI Studio (مجاني / مفتاح المستخدم)
  vertexAi,    // Google Vertex AI via Back4App (مدفوع / إنتاجي) 🆕
  openai,
  groq,
  deepseek,
  anthropic,
  kling,
  stability,
  removebg,
  azure,
  serpapi,
  github,
  openrouter,
  higgsfield,
  telegram,
  custom;

  String get displayName {
    switch (this) {
      case ProviderType.gemini:
        return "Google AI Studio";
      case ProviderType.vertexAi:
        return "Google Vertex AI";
      case ProviderType.openai:
        return "OpenAI Model";
      case ProviderType.groq:
        return "Groq Engine";
      case ProviderType.deepseek:
        return "DeepSeek Model";
      case ProviderType.anthropic:
        return "Claude (Anthropic)";
      case ProviderType.kling:
        return "Kling AI";
      case ProviderType.stability:
        return "Stability AI";
      case ProviderType.removebg:
        return "Remove.bg";
      case ProviderType.azure:
        return "Azure OpenAI";
      case ProviderType.serpapi:
        return "Google AI Mode (SerpApi)";
      case ProviderType.github:
        return "GitHub Models (GPT-4o)";
      case ProviderType.openrouter:
        return "OpenRouter (Gemini/Refined)";
      case ProviderType.higgsfield:
        return "Higgsfield AI";
      case ProviderType.telegram:
        return "Telegram Bot";
      case ProviderType.custom:
        return "Custom Server";
    }
  }

  String get iconPath {
    switch (this) {
      case ProviderType.gemini:
        return '🤖';
      case ProviderType.vertexAi:
        return '🌩️';
      case ProviderType.openai:
        return '🧠';
      case ProviderType.groq:
        return '⚡';
      case ProviderType.deepseek:
        return '🔎';
      case ProviderType.anthropic:
        return '🧭';
      case ProviderType.kling:
        return '🎬';
      case ProviderType.stability:
        return '🎨';
      case ProviderType.removebg:
        return '✂️';
      case ProviderType.azure:
        return '☁️';
      case ProviderType.serpapi:
        return '🌐';
      case ProviderType.github:
        return '🐙';
      case ProviderType.openrouter:
        return '🚦';
      case ProviderType.higgsfield:
        return '🎬';
      case ProviderType.telegram:
        return '✈️';
      case ProviderType.custom:
        return '🔌';
    }
  }

  String get defaultEndpoint {
    switch (this) {
      case ProviderType.openai:
        return 'https://api.openai.com';
      case ProviderType.gemini:
        return '';
      case ProviderType.vertexAi:
        // يتصل عبر Back4App — لا endpoint محلي
        return '';
      case ProviderType.groq:
      case ProviderType.deepseek:
      case ProviderType.anthropic:
      case ProviderType.kling:
      case ProviderType.stability:
      case ProviderType.removebg:
      case ProviderType.azure:
      case ProviderType.serpapi:
      case ProviderType.github:
      case ProviderType.openrouter:
      case ProviderType.higgsfield:
      case ProviderType.telegram:
      case ProviderType.custom:
        return '';
    }
  }

  String get apiKeyUrl {
    switch (this) {
      case ProviderType.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case ProviderType.vertexAi:
        // يُدار عبر Back4App — لا مفتاح مباشر للمستخدم
        return 'https://console.cloud.google.com/vertex-ai';
      case ProviderType.openai:
        return 'https://platform.openai.com/api-keys';
      case ProviderType.groq:
        return 'https://console.groq.com/keys';
      case ProviderType.deepseek:
        return 'https://platform.deepseek.com/api_keys';
      case ProviderType.anthropic:
        return 'https://console.anthropic.com/settings/keys';
      case ProviderType.kling:
        return 'https://app.klingai.com/global/dev/api-key';
      case ProviderType.stability:
        return 'https://platform.stability.ai/account/keys';
      case ProviderType.removebg:
        return 'https://www.remove.bg/dashboard#api-key';
      case ProviderType.azure:
        return 'https://portal.azure.com';
      case ProviderType.serpapi:
        return 'https://serpapi.com/manage-api-key';
      case ProviderType.github:
        return 'https://github.com/settings/tokens';
      case ProviderType.openrouter:
        return 'https://openrouter.ai/keys';
      case ProviderType.higgsfield:
        return 'https://cloud.higgsfield.ai/api-keys';
      case ProviderType.telegram:
        return 'https://t.me/BotFather';
      case ProviderType.custom:
        return '';
    }
  }

  String get documentationUrl {
    switch (this) {
      case ProviderType.gemini:
        return 'https://developers.google.com/ai';
      case ProviderType.openai:
        return 'https://platform.openai.com/docs';
      case ProviderType.groq:
      case ProviderType.deepseek:
      case ProviderType.anthropic:
      case ProviderType.custom:
        return '';
      case ProviderType.kling:
        return 'https://klingai.com/';
      case ProviderType.stability:
        return 'https://platform.stability.ai/';
      case ProviderType.azure:
        return 'https://learn.microsoft.com/en-us/azure/ai-services/openai/';
      case ProviderType.removebg:
        return 'https://www.remove.bg/api';
      case ProviderType.serpapi:
        return 'https://serpapi.com/search-api';
      case ProviderType.github:
        return 'https://ai.github.com/';
      case ProviderType.openrouter:
        return 'https://openrouter.ai/docs';
      case ProviderType.higgsfield:
        return 'https://cloud.higgsfield.ai/';
      case ProviderType.telegram:
        return 'https://core.telegram.org/bots/api';
      case ProviderType.vertexAi:
        return 'https://cloud.google.com/vertex-ai/docs';
    }
  }

  String? get dashboardUrl {
    switch (this) {
      case ProviderType.gemini:
        return "https://aistudio.google.com/app/apikey";
      case ProviderType.openai:
        return "https://platform.openai.com/api-keys";
      case ProviderType.groq:
        return "https://console.groq.com/keys";
      case ProviderType.deepseek:
        return "https://platform.deepseek.com/api_keys";
      case ProviderType.anthropic:
        return "https://console.anthropic.com/settings/keys";
      case ProviderType.openrouter:
        return "https://openrouter.ai/workspaces/default/keys";
      case ProviderType.kling:
        return "https://klingai.com/";
      case ProviderType.higgsfield:
        return "https://cloud.higgsfield.ai/";
      case ProviderType.github:
        return "https://github.com/settings/tokens";
      case ProviderType.stability:
        return "https://platform.stability.ai/account/keys";
      case ProviderType.removebg:
        return "https://www.remove.bg/dashboard#api-key";
      case ProviderType.serpapi:
        return "https://serpapi.com/dashboard";
      case ProviderType.telegram:
        return "https://t.me/BotFather";
      case ProviderType.vertexAi:
        return "https://console.cloud.google.com/vertex-ai";
      case ProviderType.azure:
      case ProviderType.custom:
        return null;
    }
  }

  bool get isTextCapable {
    switch (this) {
      case ProviderType.gemini:
      case ProviderType.vertexAi:  // 🆕 Vertex AI يدعم النصوص
      case ProviderType.openai:
      case ProviderType.groq:
      case ProviderType.deepseek:
      case ProviderType.anthropic:
      case ProviderType.azure:
      case ProviderType.serpapi:
      case ProviderType.github:
      case ProviderType.openrouter:
        return true;
      case ProviderType.kling:
      case ProviderType.stability:
      case ProviderType.removebg:
      case ProviderType.higgsfield:
      case ProviderType.telegram:
      case ProviderType.custom:
        return false;
    }
  }

  bool get isVideoCapable {
    switch (this) {
      case ProviderType.kling:
      case ProviderType.higgsfield:
      case ProviderType.openrouter:
        return true;
      default:
        return false;
    }
  }

  bool get isVisionCapable {
    switch (this) {
      case ProviderType.gemini:
      case ProviderType.vertexAi:  // 🆕 Vertex AI يدعم الرؤية (Vision)
      case ProviderType.openai:
      case ProviderType.azure:
      case ProviderType.github:
      case ProviderType.openrouter:
        return true;
      default:
        return false;
    }
  }

  bool get requiresSecretKey {
    switch (this) {
      case ProviderType.kling:
      case ProviderType.higgsfield:
      case ProviderType.telegram:
        return true;
      default:
        return false;
    }
  }
}

class ApiProvider {
  final ProviderType type;
  final String apiKey;
  final String? customEndpoint;
  final bool? lastTestSuccess;
  final DateTime? lastTested;

  ApiProvider({
    required this.type,
    required this.apiKey,
    this.customEndpoint,
    this.lastTestSuccess,
    this.lastTested,
  });

  bool get isValid => apiKey.trim().isNotEmpty;

  factory ApiProvider.fromJson(Map<String, dynamic> json) => ApiProvider.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  factory ApiProvider.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] ?? 'custom').toString();
    final type = ProviderType.values.firstWhere(
      (e) => e.name == typeStr || e.toString().split('.').last == typeStr,
      orElse: () => ProviderType.custom,
    );

    DateTime? parsedDate;
    if (map['lastTested'] != null) {
      try {
        parsedDate = DateTime.parse(map['lastTested'].toString());
      } catch (_) {
        parsedDate = null;
      }
    }

    return ApiProvider(
      type: type,
      apiKey: map['apiKey']?.toString() ?? (map['api_key']?.toString() ?? ''),
      customEndpoint: map['customEndpoint']?.toString() ?? map['custom_endpoint']?.toString(),
      lastTestSuccess: map['lastTestSuccess'] is bool ? map['lastTestSuccess'] : null,
      lastTested: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'api_key': apiKey,
      'custom_endpoint': customEndpoint,
      'last_test_success': lastTestSuccess,
      'last_tested': lastTested?.toIso8601String(),
    };
  }

  ApiProvider copyWith({
    ProviderType? type,
    String? apiKey,
    String? customEndpoint,
    bool? lastTestSuccess,
    DateTime? lastTested,
  }) =>
      ApiProvider(
        type: type ?? this.type,
        apiKey: apiKey ?? this.apiKey,
        customEndpoint: customEndpoint ?? this.customEndpoint,
        lastTestSuccess: lastTestSuccess ?? this.lastTestSuccess,
        lastTested: lastTested ?? this.lastTested,
      );

  @override
  String toString() {
    return 'ApiProvider(type: ${type.name}, apiKey: ${apiKey.isEmpty ? "<empty>" : "<redacted>"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiProvider &&
        other.type == type &&
        other.apiKey == apiKey;
  }

  @override
  int get hashCode => type.hashCode ^ apiKey.hashCode;
}

class AiResult {
  final String description;
  final String? productName;
  final List<String> tags;
  final String provider;

  AiResult({
    required this.description,
    this.productName,
    this.tags = const [],
    required this.provider,
  });

  @override
  String toString() =>
      'AiResult(provider: $provider, desc: $description, tags: $tags)';
}