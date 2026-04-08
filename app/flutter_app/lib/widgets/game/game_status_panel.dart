import 'package:flutter/material.dart';

class GameStatusPanel extends StatelessWidget {
  final String title;
  final String message;
  final List<String> detailLines;
  final int maxMessageLines;
  final bool compact;

  const GameStatusPanel({
    super.key,
    required this.title,
    required this.message,
    this.detailLines = const [],
    this.maxMessageLines = 2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...detailLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: compact ? 14 : 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: maxMessageLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
