import '../agents/mock_product_research_agent.dart';
import '../../services/ai_provider.dart';
import '../memory/agent_memory.dart';
import 'agent_models.dart' as core_models;
import 'agent_feature_flags.dart';

class AgentRouter {
  final AIProvider aiProvider;
  final AgentMemory memory;

  AgentRouter({
    required this.aiProvider,
    required this.memory,
  });

  /// 🧭 Dispatches requests ONLY if the feature flag is enabled.
  /// Otherwise, it returns a fast fallback to maintain project stability.
  Future<core_models.AgentResult> route(
      core_models.AgentRequest request) async {
    // 🛡️ Strict Feature Flag check for CTO-level system decoupling.
    if (!AgentFeatureFlags.mockModeEnabled &&
        !AgentFeatureFlags.architectureValidationEnabled) {
      return core_models.AgentResult<String>(
        type: core_models.AgentResultType.error,
        data: "AGENT_SYSTEM_DISABLED",
        executionTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final message = request.userMessage.toLowerCase();

    // 🔬 Capability-based routing (Mock keyword used for current validation stage)
    if (message.contains("mock")) {
      final agent = MockProductResearchAgent(
        aiProvider: aiProvider,
        memory: memory,
      );

      return await agent.execute(request);
    }

    return core_models.AgentResult<String>(
      type: core_models.AgentResultType.error,
      data:
          "AGENT_NOT_HANDLED", // Specific code for Orchestrator to continue legacy flow
      executionTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
