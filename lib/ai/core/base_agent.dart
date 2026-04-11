import '../../services/ai_provider.dart';
import '../../ai/memory/agent_memory.dart';
import 'agent_models.dart';

abstract class BaseAgent {
  final AIProvider aiProvider;
  final AgentMemory memory;
  // final List<BaseTool> tools; // Will add when Tool class is defined

  BaseAgent({
    required this.aiProvider,
    required this.memory,
  });

  /// The main execution logic for the agent.
  /// Must be implemented by specialized agents.
  Future<AgentResult> execute(AgentRequest request);

  /// Helper to check if the agent can handle a specific capability.
  bool canHandle(String capability);
}
