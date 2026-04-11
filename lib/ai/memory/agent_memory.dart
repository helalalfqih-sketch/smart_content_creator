class AgentMemory {
  // 🧠 In-Memory Singleton for high performance (Zero Latency)
  // Internal private constructor
  AgentMemory._internal();

  // Static instance
  static final AgentMemory _instance = AgentMemory._internal();

  // Factory constructor returns the same instance
  factory AgentMemory() => _instance;

  final Map<String, dynamic> _memory = {};

  /// 📥 Generic getter
  T? get<T>(String key) => _memory[key] as T?;

  /// 📤 Simple setter
  void set(String key, dynamic value) => _memory[key] = value;

  /// 🧹 Clear memory for testing
  void clear() => _memory.clear();
}
