import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_models.dart';

/// 🤖 ResearchResultWidget - A premium, structured display for Bing Copilot research.
/// Handles nested layers: Headings, Tables, Lists, and Citations.
class ResearchResultWidget extends StatelessWidget {
  final ExpertResearchData data;
  final List<SuggestedAction>? actions;

  const ResearchResultWidget({
    super.key,
    required this.data,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section
          if (data.header != null) _buildHeader(data.header!),

          // 2. Content Blocks
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.textBlocks.map((block) => _buildBlock(block)).toList(),
            ),
          ),

          // 3. References Section
          if (data.references.isNotEmpty) _buildReferences(),

          // 4. Actions Section
          if (actions != null && actions!.isNotEmpty) _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.15),
            Colors.purple.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_outlined, color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        "تقرير بحثي احترافي 🧠",
                        style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ميزات') || lower.contains('إيجابيات') || lower.contains('pros') || lower.contains('advantages')) {
      return Icons.star_rounded;
    }
    if (lower.contains('عيوب') || lower.contains('سلبيات') || lower.contains('cons') || lower.contains('disadvantages') || lower.contains('تحذير')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('خلاصة') || lower.contains('استنتاج') || lower.contains('summary') || lower.contains('conclusion')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (lower.contains('سعر') || lower.contains('توفير') || lower.contains('price') || lower.contains('cost')) {
      return Icons.payments_outlined;
    }
    return Icons.info_outline_rounded;
  }

  Color _getSectionColor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ميزات') || lower.contains('إيجابيات') || lower.contains('pros')) return Colors.greenAccent;
    if (lower.contains('عيوب') || lower.contains('سلبيات') || lower.contains('cons')) return Colors.redAccent;
    if (lower.contains('خلاصة') || lower.contains('استنتاج')) return Colors.amberAccent;
    return Colors.blueAccent;
  }

  Widget _buildBlock(dynamic block) {
    if (block is! Map) return const SizedBox.shrink();
    
    final type = block['type'];
    final snippet = block['snippet'] ?? '';

    switch (type) {
      case 'heading':
        final level = block['level'] ?? 2;
        final color = _getSectionColor(snippet);
        return Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Row(
            children: [
              Icon(_getSectionIcon(snippet), color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snippet,
                  style: TextStyle(
                    color: color,
                    fontSize: level == 2 ? 19 : 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
            ],
          ),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            snippet,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        );

      case 'list':
        final items = block['list'] as List?;
        if (items == null) return const SizedBox.shrink();
        return Column(
          children: items.map((item) => _buildListItem(item)).toList(),
        );

      case 'table':
        return _buildTable(Map<String, dynamic>.from(block));

      case 'code_block':
        return _buildCodeBlock(Map<String, dynamic>.from(block));

      default:
        return Text(snippet, style: const TextStyle(color: Colors.white));
    }
  }

  Widget _buildListItem(dynamic item) {
    final snippet = item is Map ? item['snippet'] : item.toString();
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              snippet,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14.5,
                height: 1.5,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(Map<String, dynamic> block) {
    final headers = block['headers'] as List?;
    final rows = block['table'] as List?;
    if (headers == null || rows == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.05)),
          columns: headers
              .map((h) => DataColumn(
                  label: Text(h.toString(), style: const TextStyle(color: Colors.blueAccent))))
              .toList(),
          rows: rows.map((row) {
            final rowList = row as List;
            return DataRow(
              cells: rowList
                  .map((cell) => DataCell(
                      Text(cell.toString(), style: const TextStyle(color: Colors.white70))))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(Map<String, dynamic> block) {
    final code = block['code'] ?? '';
    final lang = block['language'] ?? 'code';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.toString().toUpperCase(), 
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferences() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              const Text(
                "المصادر والمراجع الموثقة:",
                style: TextStyle(
                  color: Colors.white54, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.references.map((ref) {
              final title = ref['source'] ?? ref['title'] ?? 'مصدر خارجي';
              final link = ref['link'];
              return InkWell(
                onTap: () => _launchUrl(link),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        title, 
                        style: const TextStyle(
                          color: Colors.blueAccent, 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
      child: Wrap(
        spacing: 8,
        children: actions!.map((action) => _buildActionButton(action)).toList(),
      ),
    );
  }

  Widget _buildActionButton(SuggestedAction action) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () {
        // Handle action trigger
      },
      child: Text(action.label),
    );
  }

  void _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
