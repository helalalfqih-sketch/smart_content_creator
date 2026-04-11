import '../core/base_agent.dart';
import '../core/agent_models.dart';

class MockProductResearchAgent extends BaseAgent {
  MockProductResearchAgent({
    required super.aiProvider,
    required super.memory,
  });

  @override
  Future<AgentResult> execute(AgentRequest request) {
    // 🚀 Pure Synchronous execution for Mock (Architecture Validation phase)
    // No async, no await, no Timer - ensuring near-zero execution time.

    if (request.userMessage.isEmpty) {
      return Future.value(AgentResult.error("Message is empty"));
    }

    final mockData = ProductGalleryData(
      title: 'Foam Toy Plane (Mock)',
      imageUrls: [
        'https://placehold.co/600x400/blue/white?text=Mock+Plane+1',
        'https://placehold.co/600x400/green/white?text=Mock+Plane+2',
        'https://placehold.co/600x400/red/white?text=Mock+Plane+3',
      ],
      priceRange:
          r'$5.00 - $12.50', // 🛡️ Using raw string to avoid interpolation issues
      analysis:
          'Architecture Validation: UI rendering test for product gallery.',
    );

    return Future.value(AgentResult<ProductGalleryData>(
      type: AgentResultType.productGallery,
      data: mockData,
      executionTimestamp: DateTime.now().millisecondsSinceEpoch,
      reasoning: '🚀 [AGENT_SYSTEM_V2_STABLE] - Rendering Gallery Now.',
      actions: [
        const SuggestedAction(
          label: 'Success Test',
          toolId: 'ui_callback',
        ),
      ],
    ));
  }

  @override
  bool canHandle(String capability) {
    return capability == 'product_research';
  }
}
