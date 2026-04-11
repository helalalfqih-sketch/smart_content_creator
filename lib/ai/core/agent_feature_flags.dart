class AgentFeatureFlags {
  // 🛡️ Safety first: Mock mode is now ENABLED for architecture validation.
  static bool mockModeEnabled = true;

  // 🧪 Architecture Validation: Just logs, doesn't block legacy pipeline.
  static bool architectureValidationEnabled = true;

  /// Enable mock mode for internal architecture validation sessions.
  static void enableMockMode() {
    mockModeEnabled = true;
  }

  /// Instant kill-switch to revert to the legacy fast pipeline.
  static void disableMockMode() {
    mockModeEnabled = false;
  }

  static void enableValidationMode() {
    architectureValidationEnabled = true;
  }

  static void disableValidationMode() {
    architectureValidationEnabled = false;
  }
}
