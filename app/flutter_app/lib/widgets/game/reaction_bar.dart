import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  final VoidCallback onTapLaugh;
  final VoidCallback onTapWow;
  final VoidCallback onTapClap;
  final VoidCallback onTapFire;
  final VoidCallback onTapClose;
  final VoidCallback onTapNear;

  const ReactionBar({
    super.key,
    required this.onTapLaugh,
    required this.onTapWow,
    required this.onTapClap,
    required this.onTapFire,
    required this.onTapClose,
    required this.onTapNear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _ReactionChip(label: 'ㅋㅋ', onTap: onTapLaugh),
          _ReactionChip(label: '와!', onTap: onTapWow),
          _ReactionChip(label: '👏', onTap: onTapClap),
          _ReactionChip(label: '🔥', onTap: onTapFire),
          _ReactionChip(label: '아깝다!', onTap: onTapClose),
          _ReactionChip(label: '😱', onTap: onTapNear),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReactionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
