import 'package:flutter/material.dart';
import '../core/agent_models.dart';
import 'product_gallery_widget.dart';
import 'video_discovery_widget.dart';
import 'expert_research_widget.dart';
import 'image_gallery_widget.dart';
import 'content_plan_widget.dart';

/// 🧭 AgentResultRenderer - The centralized factory for rendering agent outputs.
/// Decouples the message bubble from the specific result implementation.
class AgentResultRenderer {
  /// Main entry point to build a widget from an AgentResult.
  static Widget render(AgentResult result) {
    // Silencing noisy build logs for production
    // debugPrint("----------------------------");
    // debugPrint("🎨 AgentResultRenderer: render called");
    // debugPrint("🎨 Type: ${result.type}");
    // debugPrint("🎨 Data RuntimeType: ${result.data.runtimeType}");

    switch (result.type) {
      case AgentResultType.productGallery:
        if (result.data is ProductGalleryData) {
          return ProductGalleryWidget(
            data: result.data as ProductGalleryData,
            actions: result.actions,
          );
        }
        return _buildError(
            "Data is ${result.data.runtimeType}, expected ProductGalleryData");

      case AgentResultType.videoDiscovery:
        if (result.data is VideoDiscoveryData) {
          return VideoDiscoveryWidget(
            data: result.data as VideoDiscoveryData,
            actions: result.actions,
          );
        }
        return _buildError(
            "Data is ${result.data.runtimeType}, expected VideoDiscoveryData");

      case AgentResultType.expertResearch:
        if (result.data is ExpertResearchData) {
          return ResearchResultWidget(
            data: result.data as ExpertResearchData,
            actions: result.actions,
          );
        }
        return _buildError(
            "Data is ${result.data.runtimeType}, expected ExpertResearchData");

      case AgentResultType.imageGallery:
        if (result.data is ImageGalleryData) {
          return ImageGalleryWidget(
            data: result.data as ImageGalleryData,
            actions: result.actions,
          );
        }
        return _buildError(
            "Data is ${result.data.runtimeType}, expected ImageGalleryData");

      case AgentResultType.contentPlan:
        if (result.data is ContentPlanData) {
          return ContentPlanWidget(
            data: result.data as ContentPlanData,
            actions: result.actions,
          );
        }
        return _buildError(
            "Data is ${result.data.runtimeType}, expected ContentPlanData");

      case AgentResultType.text:
        return _buildTextMessage(result.data.toString());

      case AgentResultType.error:
        return _buildError(result.data.toString());

      default:
        debugPrint("⚠️ UNHANDLED TYPE: ${result.type}");
        return _buildError("Unhandled result type: ${result.type}");
    }
  }

  static Widget _buildTextMessage(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(text),
    );
  }

  static Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "❌ $message",
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
