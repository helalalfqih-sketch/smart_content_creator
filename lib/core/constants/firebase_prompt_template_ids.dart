// lib/core/constants/firebase_prompt_template_ids.dart

/// Centralized registry of Firebase AI Prompt Template IDs.
///
/// Contains ONLY template identifier strings.
/// Do NOT store prompt text, system personas, or full templates here.
class FirebasePromptTemplateIds {
  FirebasePromptTemplateIds._();

  /// 🎯 System Persona Default (Wave 1A - Canonical System Instruction)
  static const String systemPersonaDefault = 'system_persona_default';

  /// ✏️ Modification Rules Default (Wave 1A - Conditional System Instruction)
  /// Reference / migration component only.
  static const String modificationRulesDefault = 'modification_rules_default';

  /// 🛠️ System Persona with Modification Rules (Wave 1A - Combined System Instruction)
  /// Applied during modification / rewrite / edit tasks when cloud prompt templates are active.
  static const String systemPersonaModification = 'system_persona_modification';
}
