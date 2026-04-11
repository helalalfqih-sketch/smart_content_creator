enum ProviderType {
  gemini,
  openai,
  groq,
  deepseek,
  anthropic,
  kling,
  stability, // Stability AI for image generation/editing
  removebg, // Remove.bg for background removal
  azure, // Azure OpenAI
  serpapi, // 👈 1. تمت إضافة SerpApi هنا
  github, // GitHub Models (GPT-4o)
  openrouter, // OpenRouter (Advanced Models)
  custom;

  String get displayName {
    switch (this) {
      case ProviderType.gemini:
        return "Google AI";
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
      case ProviderType.serpapi: // 👈 2. اسم العرض
        return "Google AI Mode (SerpApi)";
      case ProviderType.github:
        return "GitHub Models (GPT-4o)";
      case ProviderType.openrouter:
        return "OpenRouter (Gemini/Refined)";
      case ProviderType.custom:
        return "Custom Server";
    }
  }

  String get iconPath {
    switch (this) {
      case ProviderType.gemini:
        return '🤖';
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
      case ProviderType.serpapi: // 👈 3. الأيقونة
        return '🌐'; 
      case ProviderType.github:
        return '🐙';
      case ProviderType.openrouter:
        return '🚦';
      case ProviderType.custom:
        return '🔌';
    }
  }

  String get defaultEndpoint {
    switch (this) {
      case ProviderType.openai:
        return 'https://api.openai.com';
      case ProviderType.gemini:
        return ''; // uses API key query approach
      case ProviderType.groq:
      case ProviderType.deepseek:
      case ProviderType.anthropic:
      case ProviderType.kling:
      case ProviderType.stability:
      case ProviderType.removebg:
      case ProviderType.azure:
      case ProviderType.serpapi: // 👈 4. نقطة النهاية
      case ProviderType.github:
      case ProviderType.openrouter:
      case ProviderType.custom:
        return '';
    }
  }

  String get apiKeyUrl {
    switch (this) {
      case ProviderType.gemini:
        return 'https://aistudio.google.com/app/apikey';
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
      case ProviderType.serpapi: // 👈 5. رابط الحصول على المفتاح
        return 'https://serpapi.com/manage-api-key';
      case ProviderType.github:
        return 'https://github.com/settings/tokens';
      case ProviderType.openrouter:
        return 'https://openrouter.ai/keys';
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
      case ProviderType.serpapi: // 👈 6. رابط التوثيق
        return 'https://serpapi.com/search-api';
      case ProviderType.github:
        return 'https://ai.github.com/';
      case ProviderType.openrouter:
        return 'https://openrouter.ai/docs';
    }
  }

  bool get isTextCapable {
    switch (this) {
      case ProviderType.kling:
      case ProviderType.stability:
      case ProviderType.removebg:
      case ProviderType.serpapi: // 👈 SerpApi للبحث ووضع AI المحسن
        return true;
      default:
        return true;
    }
  }

  bool get isVideoCapable {
    switch (this) {
      case ProviderType.kling:
        return true;
      default:
        return false;
    }
  }

  bool get isVisionCapable {
    switch (this) {
      case ProviderType.gemini:
      case ProviderType.openai:
      case ProviderType.azure:
      case ProviderType.github:
      case ProviderType.openrouter:
        return true;
      default:
        return false;
    }
  }

  /// Whether this provider requires a separate Secret Key (in addition to API Key)
  bool get requiresSecretKey {
    switch (this) {
      case ProviderType.kling:
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

  // JSON serialization (Legacy - now using fromMap/toMap for consistency)
  factory ApiProvider.fromJson(Map<String, dynamic> json) => ApiProvider.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  /// 🛠️ تحويل الخريطة (Map) إلى كائن (Object) - لقاعدة البيانات
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
    } else if (map['last_tested'] != null) {
      try {
        parsedDate = DateTime.parse(map['last_tested'].toString());
      } catch (_) {
        parsedDate = null;
      }
    }

    return ApiProvider(
      type: type,
      apiKey: map['apiKey']?.toString() ?? (map['api_key']?.toString() ?? ''),
      customEndpoint: map['customEndpoint']?.toString() ?? map['custom_endpoint']?.toString(),
      lastTestSuccess:
          map['lastTestSuccess'] is bool ? map['lastTestSuccess'] : (map['last_test_success'] is bool ? map['last_test_success'] : null),
      lastTested: parsedDate,
    );
  }

  /// 🛠️ تحويل الكائن (Object) إلى خريطة (Map) - لقاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'api_key': apiKey,
      'custom_endpoint': customEndpoint,
      'last_test_success': lastTestSuccess,
      'last_tested': lastTested?.toIso8601String(),
    };
  }

  // new: convenience copyWith
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
    return 'ApiProvider(type: ${type.toString().split(".").last}, apiKey: ${apiKey.isEmpty ? "<empty>" : "<redacted>"}, lastTestSuccess: $lastTestSuccess, lastTested: $lastTested)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiProvider &&
        other.type == type &&
        other.apiKey == apiKey &&
        other.customEndpoint == customEndpoint &&
        other.lastTestSuccess == lastTestSuccess &&
        other.lastTested == lastTested;
  }

  @override
  int get hashCode =>
      type.hashCode ^
      apiKey.hashCode ^
      (customEndpoint?.hashCode ?? 0) ^
      (lastTestSuccess?.hashCode ?? 0) ^
      (lastTested?.hashCode ?? 0);
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