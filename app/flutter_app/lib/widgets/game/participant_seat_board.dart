import 'package:flutter/material.dart';

class SeatReactionEntry {
  final String id;
  final String socketId;
  final String label;

  const SeatReactionEntry({
    required this.id,
    required this.socketId,
    required this.label,
  });
}

class ParticipantSeatBoard extends StatelessWidget {
  final List<dynamic> players;
  final String? currentTurnSocketId;
  final String? lastSubmittedSocketId;
  final List<dynamic>? aliveSocketIds;
  final bool showAliveState;
  final List<SeatReactionEntry> reactions;

  const ParticipantSeatBoard({
    super.key,
    required this.players,
    required this.currentTurnSocketId,
    required this.lastSubmittedSocketId,
    this.aliveSocketIds,
    this.showAliveState = false,
    this.reactions = const [],
  });

  bool _isAlive(String? socketId) {
    if (!showAliveState || socketId == null) {
      return true;
    }
    return aliveSocketIds?.contains(socketId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(players.length, (index) {
          final player = players[index];
          final socketId = player['socketId']?.toString();
          final nickname = player['nickname']?.toString() ?? '이름 없음';
          final isCurrent =
              currentTurnSocketId != null && socketId == currentTurnSocketId;
          final isLast =
              lastSubmittedSocketId != null &&
              socketId == lastSubmittedSocketId;
          final isAlive = _isAlive(socketId);
          final seatReactions = reactions
              .where((reaction) => reaction.socketId == socketId)
              .toList();

          Color backgroundColor = Colors.white;
          Color borderColor = Colors.grey.shade300;

          if (isLast) {
            backgroundColor = Colors.amber.shade100;
            borderColor = Colors.orange.shade400;
          } else if (isCurrent) {
            backgroundColor = Colors.green.shade100;
            borderColor = Colors.green.shade400;
          } else if (!isAlive) {
            backgroundColor = Colors.grey.shade300;
            borderColor = Colors.grey.shade500;
          }

          String statusLabel = '${index + 1}번';
          if (isLast) {
            statusLabel = '방금 입력';
          } else if (isCurrent) {
            statusLabel = '현재 차례';
          } else if (showAliveState) {
            statusLabel = isAlive ? '생존' : '탈출/탈락';
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 108,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (seatReactions.isNotEmpty)
                Positioned(
                  top: -34,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 92,
                        height: 54,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: List.generate(
                            seatReactions.length > 3 ? 3 : seatReactions.length,
                            (reactionIndex) {
                              final reaction = seatReactions[reactionIndex];
                              final dx = reactionIndex == 0
                                  ? 0.0
                                  : (reactionIndex.isOdd ? -16.0 : 16.0);
                              final dy = reactionIndex * 10.0;

                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: _SeatReactionBadge(
                                  key: ValueKey(reaction.id),
                                  label: reaction.label,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SeatReactionBadge extends StatelessWidget {
  final String label;

  const _SeatReactionBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, opacity, child) {
            return Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
