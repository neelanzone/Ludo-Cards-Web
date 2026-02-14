class PlayedCard {
  final String cardTemplateId; // e.g. "Attack01"
  final int turnPlayed; // Turn number when played
  
  const PlayedCard({
    required this.cardTemplateId,
    required this.turnPlayed,
  });
  
  Map<String, dynamic> toJson() => {
    'cardTemplateId': cardTemplateId,
    'turnPlayed': turnPlayed,
  };
  
  factory PlayedCard.fromJson(Map<String, dynamic> json) => PlayedCard(
    cardTemplateId: json['cardTemplateId'] as String,
    turnPlayed: json['turnPlayed'] as int,
  );
}
