import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  static const int handSize = 5;
  static const Duration animDuration = Duration(milliseconds: 250);
  // how “tall” the arch is (pixels). Increase for a stronger arch.
  static const double archHeight = 34;

  // ---- CONFIG: change repeat rates per category here ----
  // Assumes filenames like: assets/cards/Attack01.png, Defence07.png, Board12.png, Movement08.png
  static const List<_Group> _groups = [
    _Group(prefix: 'Attack', count: 6, type: _CardType.attack, copies: 2),
    _Group(prefix: 'Defence', count: 7, type: _CardType.defense, copies: 2),
    _Group(prefix: 'Board', count: 12, type: _CardType.manipulation, copies: 1),
    _Group(prefix: 'Movement', count: 8, type: _CardType.movement, copies: 2),
  ];

  late final AnimationController _deckShakeController;

  bool _isBusy = false;
  int? _animatingSlotIndex;
  bool _isDiscarding = false;

  int? _hoverIndex;

    static const double cardW = 110;
    static const double cardH = 160;

    // overlap amount: higher = more overlap
    static const double overlap = 42;

    // fan curvature: higher = more rotation spread
    static const double fanAngle = 0.22; // ~12.6 degrees max

  late final List<_Card> _drawPile = _buildDrawPileByGroup(_groups);
  final List<_Card> _discardPile = [];
  late List<_Card> _hand;

  @override
  void initState() {
    super.initState();
    _deckShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _hand = List.generate(handSize, (_) => _draw());
  }

  @override
  void dispose() {
    _deckShakeController.dispose();
    super.dispose();
  }

  // Builds deck with repeats per category.
  // Example: Attack(6)*2 + Defence(7)*2 + Board(12)*1 + Movement(8)*2 = 46 cards.
  List<_Card> _buildDrawPileByGroup(List<_Group> groups) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final pile = <_Card>[];
    var instance = 0;

    for (final g in groups) {
      for (int i = 1; i <= g.count; i++) {
        final num = twoDigits(i);
        final templateId = '${g.prefix}$num'; // e.g. Attack01
        final title = '${g.prefix} $num';     // optional; not shown if your PNG has text
        final asset = 'assets/cards/$templateId.png';

        for (int c = 0; c < g.copies; c++) {
          pile.add(_Card(
            id: 'D$instance',
            templateId: templateId,
            title: title,
            type: g.type,
            imageAsset: asset,
          ));
          instance++;
        }
      }
    }

    pile.shuffle();
    return pile;
  }

  _Card _draw() {
    if (_drawPile.isEmpty) {
      _drawPile.addAll(_discardPile);
      _discardPile.clear();
      _drawPile.shuffle();
    }
    return _drawPile.removeLast();
  }

  Future<void> _handleCardTap(int index) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _animatingSlotIndex = index;
      _isDiscarding = true;
    });

    _deckShakeController.forward(from: 0.0);

    await Future.delayed(animDuration);

    setState(() {
      final old = _hand[index];
      _discardPile.add(old);
      _hand[index] = _draw();
      _isDiscarding = false;
    });

    await Future.delayed(animDuration);

    setState(() {
      _animatingSlotIndex = null;
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Stack(
          children: [
            // Deck (top)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: AnimatedBuilder(
                  animation: _deckShakeController,
                  builder: (context, child) {
                    final t = _deckShakeController.value;
                    final wobble = math.sin(t * math.pi * 3) * 0.04;
                    return Transform.rotate(
                      angle: wobble,
                      child: Transform.scale(
                        scale: 1.0 + (t * 0.03),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PileWidget(
                        label: 'Draw',
                        count: _drawPile.length,
                        isDiscard: false,
                      ),
                      const SizedBox(width: 16),
                      _PileWidget(
                        label: 'Discard',
                        count: _discardPile.length,
                        isDiscard: true,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Hand (bottom) — FAN HAND
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: _fanHand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

// NOTE: _handSlot() is unused after switching to fan hand layout.
//Widget _handSlot(int index) {
//    final card = _hand[index];
//    final isThis = _animatingSlotIndex == index;

//    final offsetY = (isThis && _isDiscarding) ? 24.0 : 0.0;
//    final opacity = (isThis && _isDiscarding) ? 0.0 : 1.0;

//    return GestureDetector(
//      onTap: () => _handleCardTap(index),
//      child: AnimatedOpacity(
//        duration: animDuration,
//        opacity: opacity,
//        child: AnimatedSlide(
//          duration: animDuration,
//          offset: Offset(0, offsetY / 120),
//          child: _CardWidget(card: card),
//        ),
//      ),
//    );
//  }
//}
Widget _fanHand() {
  final totalWidth = cardW + (handSize - 1) * (cardW - overlap);
  final totalHeight = cardH + 60;

  return SizedBox(
    height: totalHeight,
    child: Center(
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1) Base layer: draw all non-hover cards in stable order
            for (int i = 0; i < handSize; i++)
              if (i != _hoverIndex) _fanCard(i),

            // 2) Overlay: draw hovered card last (on top)
            if (_hoverIndex != null) _fanCard(_hoverIndex!),
          ],
        ),
      ),
    ),
  );
}


  Widget _fanCard(int index) {
    if (index < 0 || index >= _hand.length) return const SizedBox.shrink();
    final card = _hand[index];

    final left = index * (cardW - overlap);

    final mid = (handSize - 1) / 2;
    final t = (index - mid) / (mid == 0 ? 1 : mid); // -1 → +1
    // Arch curve: center card up, edges down.
    // When t=0 => archY = -archHeight (highest point)
    // When t=±1 => archY = 0 (edges baseline)
    final archY = -archHeight * (1 - (t * t));
    final angle = t * fanAngle;

    final isDiscardingThis = _animatingSlotIndex == index && _isDiscarding;
    final isHover = _hoverIndex == index;

    final lift = archY + (isHover ? -45.0 : 0.0) + (isDiscardingThis ? -40.0 : 0.0);
    final scale = isHover ? 1.12 : 1.0;
    final opacity = isDiscardingThis ? 0.0 : 1.0;

    return Positioned(
      left: left,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_isBusy) return;
          setState(() => _hoverIndex = index);
        },
        onExit: (_) {
            // Delay helps when moving across overlapping regions
           Future.microtask(() {
             if (!mounted) return;
             if (_hoverIndex == index) setState(() => _hoverIndex = null);
           });
        },
        child: GestureDetector(
          onTap: () => _handleCardTap(index),
          child: AnimatedOpacity(
            duration: animDuration,
            opacity: opacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..translate(0.0, lift)
                ..scale(scale),
              transformAlignment: Alignment.bottomCenter,
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment.bottomCenter,
                child: _CardWidget(card: card),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CardType { attack, defense, movement, manipulation }

class _Group {
  final String prefix; // Attack / Defence / Board / Movement
  final int count;     // 6 / 7 / 12 / 8
  final _CardType type;
  final int copies;    // repeat rate per card within this group

  const _Group({
    required this.prefix,
    required this.count,
    required this.type,
    required this.copies,
  });
}

class _Card {
  final String id;         // unique instance id in deck
  final String templateId; // e.g. Attack01
  final String title;
  final _CardType type;
  final String imageAsset; // e.g. assets/cards/Attack01.png

  const _Card({
    required this.id,
    required this.templateId,
    required this.title,
    required this.type,
    required this.imageAsset,
  });
}

class _PileWidget extends StatelessWidget {
  final String label;
  final int count;
  final bool isDiscard;

  const _PileWidget({required this.label, required this.count, required this.isDiscard});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDiscard ? const Color(0xFF2A1E24) : const Color(0xFF1E2A33);
    final borderColor = isDiscard ? const Color(0xFF4A2B36) : const Color(0xFF2B3A45);
    
    return SizedBox(
      width: 140,
      height: 150,
      child: Stack(
        children: [
          // deck stack
          for (int i = 0; i < 4; i++)
            Positioned(
              left: 10 + i * 3.0,
              top: 10 + i * 2.0,
              child: Container(
                width: 110,
                height: 130,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
              ),
            ),
            
 

          // draw pile count
          Positioned(
            right: 12,
            bottom: 12,
            child: _CounterPill(label: label, value: count),
          ),
        ],
      ),
    );
  }
}




class _CounterPill extends StatelessWidget {
  final String label;
  final int value;

  const _CounterPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final _Card card;
  const _CardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _GameBoardState.cardW,
      height: _GameBoardState.cardH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          card.imageAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stack) {
            return Container(
              color: const Color(0xFF161D24),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Missing:\n${card.imageAsset}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }
}
