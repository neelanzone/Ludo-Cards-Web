import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ludo_rpg/models/played_card.dart';

enum LudoColor {
  red,
  green,
  yellow,
  blue,
}

extension LudoColorExt on LudoColor {
  String toShortString() => toString().split('.').last;
  static LudoColor fromString(String s) => LudoColor.values.firstWhere((e) => e.toShortString() == s, orElse: () => LudoColor.red);
}

enum TokenStatus { alive, dead, finished }

extension TokenStatusExt on TokenStatus {
  String toShortString() => toString().split('.').last;
  static TokenStatus fromString(String s) => TokenStatus.values.firstWhere((e) => e.toShortString() == s, orElse: () => TokenStatus.alive);
}

class ActiveEffect {
  final String id; // e.g. "Shield", "Stun"
  final int duration; // Turns remaining
  final int value; // e.g. +4 range, or boolean equivalent
  final Map<String, dynamic> data;
  
  const ActiveEffect({required this.id, required this.duration, this.value = 0, this.data = const {}});
  Map<String, dynamic> toJson() => {
    'id': id,
    'duration': duration,
    'value': value,
    'data': data,
  };

  factory ActiveEffect.fromJson(Map<String, dynamic> json) => ActiveEffect(
    id: json['id'] as String,
    duration: json['duration'] as int,
    value: json['value'] ?? 0,
    data: json['data'] ?? {},
  );
}

class LudoToken {
  final String id;
  final LudoColor color;

  /// **STRICT RELATIVE POSITIONING**
  /// -1: Base (Safe)
  /// 0..51: Main Track (Relative to THIS token's start color)
  /// 52..57: Home Stretch (Relative, 0th step is 52)
  /// 99: Goal/Finished
  int position;
  TokenStatus status;
  
  // Active Buffs/Debuffs (Shield, Poison, etc.)
  List<ActiveEffect> effects;

  LudoToken({
    required this.id,
    required this.color,
    this.position = -1,
    this.status = TokenStatus.alive,
    this.hp = 1,
    this.maxHp = 1,
    List<ActiveEffect>? effects,
  }) : effects = effects ?? [];

  int hp;
  int maxHp;

  bool get isInBase => position == -1;
  bool get isOnMain => position >= 0 && position < 52;
  bool get isInHomeStretch => position >= 52 && position <= 57;
  bool get isFinished => status == TokenStatus.finished || position == 99;
  bool get isDead => status == TokenStatus.dead;
  
  bool hasEffect(String effectId) => effects.any((e) => e.id == effectId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color.toShortString(),
    'position': position,
    'status': status.toShortString(),
    'hp': hp,
    'maxHp': maxHp,
    'effects': effects.map((e) => e.toJson()).toList(),
  };

  factory LudoToken.fromJson(Map<String, dynamic> json) => LudoToken(
    id: json['id'],
    color: LudoColorExt.fromString(json['color']),
    position: json['position'],
    status: TokenStatusExt.fromString(json['status'] ?? 'alive'),
    hp: json['hp'] ?? 1,
    maxHp: json['maxHp'] ?? 1,
    effects: (json['effects'] as List?)?.map((e) => ActiveEffect.fromJson(e)).toList() ?? [],
  );
}

class LudoPlayer {
  final String id;
  final LudoColor color;
  final List<LudoToken> tokens;
  
  // Player-level effects (Stunned/Skipped, Extra Turn, etc.)
  List<ActiveEffect> effects;
  
  // Recently played cards (last 2)
  List<PlayedCard> recentPlays; 

  LudoPlayer({
    required this.id,
    required this.color,
    required this.tokens,
    List<ActiveEffect>? effects,
    List<PlayedCard>? recentPlays,
  }) : effects = effects ?? [],
       recentPlays = recentPlays ?? [];
  
  bool hasEffect(String effectId) => effects.any((e) => e.id == effectId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color.toShortString(),
    'tokens': tokens.map((t) => t.toJson()).toList(),
    'effects': effects.map((e) => e.toJson()).toList(),
    'recentPlays': recentPlays.map((p) => p.toJson()).toList(),
  };

  factory LudoPlayer.fromJson(Map<String, dynamic> json) => LudoPlayer(
    id: json['id'],
    color: LudoColorExt.fromString(json['color']),
    tokens: (json['tokens'] as List).map((t) => LudoToken.fromJson(t)).toList(),
    effects: (json['effects'] as List?)?.map((e) => ActiveEffect.fromJson(e)).toList() ?? [],
    recentPlays: (json['recentPlays'] as List?)?.map((p) => PlayedCard.fromJson(p)).toList() ?? [],
  );
}

// Visual Effects for Animation
abstract class VisualEffect {
  final int durationMs;
  final DateTime startTime;
  
  VisualEffect({required this.durationMs}) : startTime = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(startTime).inMilliseconds > durationMs;
}


class LaserVisualEffect extends VisualEffect {
  final Point<int> origin; // Grid coordinates (0..14)
  final bool horizontal;
  
  LaserVisualEffect({required this.origin, required this.horizontal, super.durationMs = 800});
}
