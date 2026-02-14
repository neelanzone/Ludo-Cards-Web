import 'package:flutter/material.dart';
import 'package:ludo_rpg/models/core.dart';
import 'package:ludo_rpg/models/played_card.dart';
import 'package:ludo_rpg/data/card_library.dart';

/// Displays a player's recently played cards (last 2)
class RecentPlayedCards extends StatelessWidget {
  final LudoPlayer player;
  final LudoColor position; // Which corner to display in
  
  const RecentPlayedCards({
    super.key,
    required this.player,
    required this.position,
  });
  
  @override
  Widget build(BuildContext context) {
    if (player.recentPlays.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < player.recentPlays.length && i < 2; i++)
          _buildCardThumbnail(player.recentPlays[i]),
      ],
    );
  }
  
  Widget _buildCardThumbnail(PlayedCard playedCard) {
    final template = CardLibrary.getById(playedCard.cardTemplateId);
    if (template == null) return const SizedBox.shrink();
    
    return Container(
      width: 50,
      height: 70,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            template.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
