import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'models.dart';
import 'ludo_board.dart';
import 'ludo_rpg_engine.dart';
import 'dice_widget.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  static const int minHandSize = 5;
  static const int maxHandSize = 7;
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
  Future<void> _drawOneToHand() async {
    if (_isBusy) return;
    if (_hand.length >= maxHandSize) return;

    setState(() {
      _hand.add(_draw());
      _hoverIndex = null;
    });
  }

  Future<void> _drawToFullHand() async {
    if (_isBusy) return;
    if (_hand.length >= minHandSize) return;

    final needed = (minHandSize - _hand.length);
    setState(() {
      for (int i = 0; i < needed; i++) {
        if (_hand.length >= maxHandSize) break;
        _hand.add(_draw());
      }
      _hoverIndex = null;
    });
  }
  late final AnimationController _deckShakeController;

  bool _isBusy = false;
  int? _animatingSlotIndex;
  bool _isDiscarding = false;
  int? _hoverIndex;
  bool _isRolling = false;
  
  // Interactive Move Selection
  final Set<int> _selectedDiceIndices = {}; // 0 for A, 1 for B
  String? _selectedTokenId;
  
  int _visualA = 4;
  int _visualB = 4;
  final math.Random _rng = math.Random.secure(); // Secure random for better distribution

  // Ludo Engine
  late final LudoRpgEngine _engine;
  late final LudoRpgGameState _ludo;

  static const double cardW = 110;
  static const double cardH = 160;
  static const double overlap = 42;
  static const double fanAngle = 0.22;

  // Multi-Player Card State
  final Map<LudoColor, List<_Card>> _drawPiles = {};
  final Map<LudoColor, List<_Card>> _discardPiles = {};
  final Map<LudoColor, List<_Card>> _hands = {};

  // Accessors for CURRENT player (to minimize refactor noise)
  List<_Card> get _hand => _hands[_ludo.currentPlayer.color]!;
  List<_Card> get _drawPile => _drawPiles[_ludo.currentPlayer.color]!;
  List<_Card> get _discardPile => _discardPiles[_ludo.currentPlayer.color]!;

  @override
  void initState() {
    super.initState();
    _deckShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize Engine
    _engine = LudoRpgEngine();
    _ludo = LudoRpgGameState(players: _buildDefaultPlayers());

    // Initialize Decks and Hands for ALL players
    for (var color in LudoColor.values) {
        _drawPiles[color] = _generateDeck();
        _discardPiles[color] = [];
        _hands[color] = [];
        
        // Initial Draw
        for(int i=0; i<minHandSize; i++) {
             _hands[color]!.add(_drawFromSpecific(color));
        }
    }
  }

  // Generate a full deck from the Library
  List<_Card> _generateDeck() {
      List<_Card> deck = [];
      // Flatten library into a deck list
      // For MVP, add 1 copy of every card? Or duplicates?
      // Let's add 2 copies of standard cards, 1 of legendary/rare.
      // Or just 1 of each for now (35 cards is a good deck size).
      
      for (var template in CardLibrary.allCards) {
          // Determine copies (Maybe library has 'rarity' later)
          // For now, 1 copy of each.
          final card = _Card(
              id: "${template.id}_${math.Random().nextInt(10000)}", 
              templateId: template.id,
              title: template.name,
              // Map effect type to visual type?
              type: _mapEffectToVisualType(template.effectType), 
              imageAsset: "assets/cards/${template.id}.png"
          );
          deck.add(card);
      }
      
      deck.shuffle();
      return deck;
  }
  
  _CardType _mapEffectToVisualType(CardEffectType type) {
      if (type.toString().contains("Attack") || type == CardEffectType.laser) return _CardType.attack;
      if (type.toString().contains("Shield") || type == CardEffectType.cure) return _CardType.defense;
      if (type.toString().contains("Move") || type == CardEffectType.teleport || type == CardEffectType.swapPos) return _CardType.movement;
      return _CardType.manipulation;
  }
  
  // Helper to draw for specific color (used during init)
  _Card _drawFromSpecific(LudoColor c) {
      if (_drawPiles[c]!.isEmpty) {
          _drawPiles[c]!.addAll(_discardPiles[c]!);
          _discardPiles[c]!.clear();
          _drawPiles[c]!.shuffle();
      }
      return _drawPiles[c]!.removeLast();
  }

  List<LudoPlayer> _buildDefaultPlayers() {
    List<LudoToken> mkTokens(LudoColor c) => List.generate(
          4,
          (i) => LudoToken(id: '${c.name}_$i', color: c),
        );

    return [
      LudoPlayer(id: 'P1', color: LudoColor.red, tokens: mkTokens(LudoColor.red)),
      LudoPlayer(id: 'P2', color: LudoColor.green, tokens: mkTokens(LudoColor.green)),
      LudoPlayer(id: 'P3', color: LudoColor.yellow, tokens: mkTokens(LudoColor.yellow)),
      LudoPlayer(id: 'P4', color: LudoColor.blue, tokens: mkTokens(LudoColor.blue)),
    ];
  }
  
  // Toggles dice selection if we are in awaitAction phase
  void _toggleDiceSelection(int index) {
      if (_ludo.phase != TurnPhase.awaitAction) return; 
      // Validate: Can't select used dice
      if (index == 0 && (_ludo.dice.aUsed || _ludo.dice.a == null)) return;
      if (index == 1 && (_ludo.dice.bUsed || _ludo.dice.b == null)) return;

      setState(() {
          if (_selectedDiceIndices.contains(index)) {
              _selectedDiceIndices.remove(index);
          } else {
              _selectedDiceIndices.add(index);
          }
      });
  }

  Future<void> _rollDice() async {
      if (_ludo.phase != TurnPhase.awaitRoll) {
          debugPrint("IGNORED ROLL: Phase is ${_ludo.phase}");
          return;
      }
      if (_isRolling) return;
      
      // 1. Lock and Roll early
      setState(() { 
          _isRolling = true; 
          _selectedDiceIndices.clear(); // Reset selection
          _selectedTokenId = null;
      });
      debugPrint("ROLL STARTED");
      _engine.rollDice(_ludo); 
      // Result is now in _ludo.dice.a/b but logic panel uses _visualA/B
      
      final delays = [80, 80, 80, 100, 100, 120, 150, 180, 220, 200];
      
      // Animate randoms for all steps EXCEPT the last one
      for (int i = 0; i < delays.length - 1; i++) {
          if (!mounted) return;
          setState(() {
              _visualA = _rng.nextInt(6) + 1;
              _visualB = _rng.nextInt(6) + 1;
          });
          await Future.delayed(Duration(milliseconds: delays[i]));
      }
      
      // For the FINAL step, show the ACTUAL result
      // This ensures the dice "lands" on the correct number and stays there during the long 'settle' delay
      if (!mounted) return;
      setState(() {
          _visualA = _ludo.dice.a!;
          _visualB = _ludo.dice.b!;
      });
      await Future.delayed(Duration(milliseconds: delays.last));
      
      // Unlock
      if (!mounted) return;
      setState(() {
          _isRolling = false;
      });
  }
  
  // Debug: simple tap handler for board to test spawn/move?
  // For now, let's just create a button to roll dice.
  
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

  // Accessors handle the logic, no change needed to _draw() 
  // EXCEPT verify it refers to the getters correctly. 
  // Since I kept the names _hand, _drawPile, _discardPile, existing code works!
  _Card _draw() {
    // Uses getters for CURRENT player
    if (_drawPile.isEmpty) {
      _drawPile.addAll(_discardPile);
      _discardPile.clear();
      _drawPile.shuffle();
    }
    return _drawPile.removeLast();
  }

  void _handleTokenTap(LudoToken token) {
      if (_ludo.phase == TurnPhase.ended) return; 
      if (token.color != _ludo.currentPlayer.color) return;

      // 1. Try Spawn (Priority, allowed in awaitRoll too)
      if (token.isInBase) {
           setState(() {
               _engine.spawnFromBase(_ludo, token);
               _selectedTokenId = null; // Clear any pending selection
           });
           return;
      } 
      
      // If we are here, we are clicking a track token. 
      // This DOES require awaitAction (dice rolled).
      if (_ludo.phase != TurnPhase.awaitAction) return;

      // 2. Interactive Selection Logic
      if (_selectedTokenId != token.id) {
          // SELECTING
          setState(() {
              _selectedTokenId = token.id;
          });
          // Optional: Auto-select dice if only one valid move? 
          // For now, let user select dice manually as requested.
      } else {
          // CONFIRMING (Double Tap on already selected token)
          if (_selectedDiceIndices.isEmpty) {
               setState(() {
                   _selectedTokenId = null; // Unselect
               });
               return;
          }

          bool useA = _selectedDiceIndices.contains(0);
          bool useB = _selectedDiceIndices.contains(1);

          setState(() {
              bool success = _engine.moveToken(gs: _ludo, token: token, useA: useA, useB: useB);
              if (success) {
                  // Move successful!
                  _selectedTokenId = null;
                  _selectedDiceIndices.clear();
                  
                  // Check if turn should end? 
                  // Engine doesn't auto-end.
                  // Keep it manual or auto? 
                  // User likes manual End Turn usually, but let's see.
                  // If no dice left, maybe show End Turn button prominent?
                  // End Turn button is visible if phase==awaitAction.
              } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Invalid Move! Check dice or path."), duration: Duration(milliseconds: 800))
                   );
              }
          });
      }
  }

  // _executeMove removed (logic inlined into confirm step)
  
  int _turnCount = 0;

  void _endTurn() {
      setState(() {
          _engine.endTurn(_ludo);
          _turnCount++;
          _visualA = 4;
          _visualB = 4;
          _hoverIndex = null;
      });
  }

  Future<void> _discardCard(int index) async {
      // Logic from old _handleCardTap
      if (_isBusy) return; 
      // Need LudoColor. Is it always current player?
      // Yes, because we only discard our own cards.
      final color = _ludo.currentPlayer.color;
      final hand = _hands[color]!;
      
      if (index < 0 || index >= hand.length) return;

      setState(() {
        _isBusy = true;
        _animatingSlotIndex = index;
        _isDiscarding = true;
      });

      // Shake ONLY discard pile
      _deckShakeController.forward(from: 0.0);

      await Future.delayed(animDuration);

      setState(() {
        final old = hand[index];
        _discardPiles[color]!.add(old);
        hand.removeAt(index);
        _isDiscarding = false;
        _hoverIndex = null;
      });

      await Future.delayed(animDuration);

      setState(() {
        _animatingSlotIndex = null;
        _isBusy = false;
      });
  }

  void _handleCardTap(int index, LudoColor color) {
    if (_isBusy || _ludo.phase == TurnPhase.ended) return;
    if (_ludo.currentPlayer.color != color) return; // Not your hand
    
    // Check pending target cancellation
    if (_ludo.phase == TurnPhase.selectingTarget) {
        setState(() {
            _ludo.phase = TurnPhase.awaitAction;
            _ludo.activeCardId = null;
             _pendingCardHandIndex = null;
        });
        return;
    }
    
    // Check actions
    if (_ludo.cardActionsRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No card actions remaining!"), duration: Duration(milliseconds: 800)));
        return;
    }

    final cardData = _hand[index];
    final template = CardLibrary.getById(cardData.templateId);
    if (template == null) return;

    if (template.targetType == TargetType.none) {
        // Instant Cast
        bool success = _engine.playCard(gs: _ludo, card: template, target: null);
        if (success) {
            _discardCard(index);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Played ${template.name}!"), duration: const Duration(milliseconds: 800)));
        }
    } else {
        // Requires Target
        setState(() {
            _ludo.phase = TurnPhase.selectingTarget;
            _ludo.activeCardId = template.id;
             _pendingCardHandIndex = index;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Select Target for ${template.name}..."), duration: const Duration(seconds: 2)));
    }
  }
  
  // Track which card slot is being played (for removal)
  int? _pendingCardHandIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(_ludo.currentPlayer.color),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Area: Decks + Board
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                   const double pileW = 140.0; 
                   const double minGap = 24.0; 
                   
                   // Determine max square size for board
                   double availW = constraints.maxWidth - 2 * (pileW + minGap);
                   double availH = constraints.maxHeight - 16;
                   double boardSize = math.min(availW, availH);
                   if (boardSize < 100) boardSize = 100; // Minimum size safety

                   return Center(
                     child: SizedBox(
                        width: boardSize + 2 * (pileW + minGap),
                        height: boardSize, // Center aligns vertically in the row
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                // Draw Deck
                                SizedBox(
                                   width: pileW, 
                                   height: 150, 
                                   child: Center(
                                      child: GestureDetector(
                                        onTap: _drawOneToHand,
                                        child: _PileWidget(label: 'Draw', count: _drawPile.length, isDiscard: false),
                                      )
                                   )
                                ),
                                
                                SizedBox(width: minGap),
                                
                                // Board (Scalable)
                                SizedBox(
                                   width: boardSize, 
                                   height: boardSize,
                                   child: Stack(
                                     alignment: Alignment.center,
                                     children: [
                                       LudoBoard(
                                           players: _ludo.players, 
                                           engine: _engine, 
                                           activeColor: _ludo.currentPlayer.color,
                                           onTokenTap: _handleTokenTap,
                                           selectedTokenId: _selectedTokenId,
                                       ),
                                       // Center Dice Overlay
                                       IgnorePointer(
                                          // If rolling is not allowed (and not rolling), maybe let clicks pass through to board center?
                                          // But dice are interactive. If canRoll is false, onTap is null.
                                          // But we want to see them always? Yes.
                                          ignoring: false, 
                                          child: SizedBox(
                                            width: 110, // Perfect balance
                                            height: 60,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                // Dice A (Left, tilted, smaller)
                                                Positioned(
                                                   left: 10, 
                                                   top: 8,
                                                   child: Transform.rotate(
                                                     angle: -0.2, 
                                                     child: DiceWidget(
                                                       value: _visualA, 
                                                       size: 45, 
                                                       isSelected: _selectedDiceIndices.contains(0),
                                                       // Enable if Rolling Allowed OR Selection Allowed
                                                       isEnabled: (_ludo.phase == TurnPhase.awaitRoll && !_isRolling) || (_ludo.phase == TurnPhase.awaitAction),
                                                       onTap: () {
                                                           if (_ludo.phase == TurnPhase.awaitRoll && !_isRolling) _rollDice();
                                                           else if (_ludo.phase == TurnPhase.awaitAction) _toggleDiceSelection(0);
                                                       },
                                                       color: _ludo.dice.aUsed ? Colors.grey : null,
                                                     ),
                                                   )
                                                ),
                                                // Dice B (Right, tilted, smaller, separate)
                                                Positioned(
                                                   right: 10, 
                                                   top: 8,
                                                   child: Transform.rotate(
                                                     angle: 0.25, 
                                                     child: DiceWidget(
                                                       value: _visualB, 
                                                       size: 45, 
                                                       isSelected: _selectedDiceIndices.contains(1),
                                                       isEnabled: (_ludo.phase == TurnPhase.awaitRoll && !_isRolling) || (_ludo.phase == TurnPhase.awaitAction),
                                                       onTap: () {
                                                           if (_ludo.phase == TurnPhase.awaitRoll && !_isRolling) _rollDice();
                                                           else if (_ludo.phase == TurnPhase.awaitAction) _toggleDiceSelection(1);
                                                       },
                                                       color: _ludo.dice.bUsed ? Colors.grey : null,
                                                     ),
                                                   )
                                                ),

                                                // Roll Button Overlay
                                                if (_ludo.phase == TurnPhase.awaitRoll && !_isRolling)
                                                  Align(
                                                    alignment: Alignment.center,
                                                    child: SizedBox(
                                                      height: 28,
                                                      child: ElevatedButton(
                                                        onPressed: _rollDice,
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.amber, 
                                                          foregroundColor: Colors.black,
                                                          elevation: 6,
                                                          shadowColor: Colors.black54,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                        ),
                                                        child: const Text("ROLL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                       ),

                                       // Tutorial Overlay (First Round Only)
                                       if (_turnCount < 4)
                                          Positioned(
                                              top: 40, // Above center dice
                                              child: _buildTutorialHint(),
                                          ),
                                     ],
                                   )
                                ),
                                
                                SizedBox(width: minGap),
                                
                                // Discard Deck
                                SizedBox(
                                   width: pileW,
                                   height: 150,
                                   child: Center(
                                      child: AnimatedBuilder(
                                        animation: _deckShakeController,
                                        builder: (context, child) {
                                          final t = _deckShakeController.value;
                                          final wobble = math.sin(t * math.pi * 3) * 0.04;
                                          final lift = -6 * math.sin(t * math.pi);
                                          return Transform.translate(
                                            offset: Offset(0, lift),
                                            child: Transform.rotate(angle: wobble, child: child),
                                          );
                                        },
                                        child: DragTarget<int>(
                                            onAccept: (index) {
                                                setState(() => _isBusy = false); // Clear drag busy state
                                                _discardCard(index);
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card Discarded"), duration: Duration(milliseconds: 600)));
                                            },
                                            builder: (context, candidateData, rejectedData) {
                                                return AnimatedScale(
                                                    scale: candidateData.isNotEmpty ? 1.1 : 1.0,
                                                    duration: const Duration(milliseconds: 200),
                                                    child: _PileWidget(
                                                        label: 'Discard', 
                                                        count: _discardPile.length, 
                                                        isDiscard: true
                                                    ),
                                                );
                                            },
                                        ),
                                      ),
                                   ),
                                ),
                            ]
                        )
                     )
                   );
                },
              ),
            ),
            
            // 2. Bottom Area: Hand + Controls
            Container(
              color: Colors.black12,
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hand Fan with Transition
                  AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                         return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                               position: Tween<Offset>(
                                  begin: const Offset(0, 0.3), 
                                  end: Offset.zero
                               ).animate(animation),
                               child: child,
                            ),
                         );
                      },
                      child: KeyedSubtree(
                          key: ValueKey(_ludo.currentPlayer.color),
                          child: _fanHand(_hand, _ludo.currentPlayer.color),
                      ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Controls Panel
                  _buildControlPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialHint() {
      if (_turnCount >= 4) return const SizedBox.shrink(); // Tutorial only for first round
      
      String text = "";
      final player = _ludo.currentPlayer;
      bool hasBaseTokens = player.tokens.any((t) => t.isInBase);

      if (_ludo.phase == TurnPhase.awaitRoll) {
          if (hasBaseTokens) {
              text = "Tap Pawn to Start or Dice to Roll";
          } else {
              text = "Tap Dice to Roll";
          }
      } else if (_ludo.phase == TurnPhase.awaitAction) {
          if (_selectedDiceIndices.isNotEmpty && _selectedTokenId != null) {
               text = "Tap Pawn AGAIN to Move";
          } else if (_selectedDiceIndices.isNotEmpty && _selectedTokenId == null) {
               text = "Tap Pawn to Select";
          } else if (_selectedDiceIndices.isEmpty) {
               if (_ludo.dice.aUsed || _ludo.dice.bUsed) {
                   text = "Select Dice or End Turn";
               } else {
                   text = "Tap Dice to Select";
               }
          }
      } 
      
      if (text.isEmpty) return const SizedBox.shrink();

      return IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,3))]
            ),
            child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 13,
                  fontFamily: 'Helvetica Neue',
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
                  ]
                ),
            ),
          )
      );
  }

  Widget _buildControlPanel() {
    // Dice are now on the board overlay
    // STRICT VISUAL MODE: Always show what's in _visualA/B.

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hand Controls
          ElevatedButton.icon(
            icon: const Icon(Icons.style),
            label: const Text('Draw Full'),
            onPressed: (_hand.length < minHandSize && !_isBusy) ? _drawToFullHand : null,
          ),
          
          const SizedBox(width: 20),
          
          // End Turn (Persistent)
          Builder(builder: (context) {
              bool canEnd = (_ludo.phase == TurnPhase.awaitAction && !_isRolling);
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: canEnd ? Colors.redAccent.shade700 : Colors.white10,
                    foregroundColor: canEnd ? Colors.white : Colors.white38,
                    disabledBackgroundColor: Colors.white10,
                    disabledForegroundColor: Colors.white38,
                ),
                icon: const Icon(Icons.stop_circle),
                label: const Text("End Turn"),
                onPressed: canEnd ? _endTurn : null,
              );
          }),
        ],
      ),
    );
  }

  Color _getColor(LudoColor c) {
      switch(c) {
          case LudoColor.red: return Colors.redAccent;
          case LudoColor.green: return Colors.greenAccent;
          case LudoColor.yellow: return Colors.amberAccent; 
          case LudoColor.blue: return Colors.cyanAccent;
      }
  }

  Color _getBackgroundColor(LudoColor c) {
      // Dark muted hues for background
      switch(c) {
          case LudoColor.red: return const Color(0xFF4A102A); // Rose Red
          case LudoColor.green: return const Color(0xFF102810);
          case LudoColor.yellow: return const Color(0xFF3C3C05); // Lemon Yellow (Dark)
          case LudoColor.blue: return const Color(0xFF101828);
      }
  }
// Old _handSlot removed...

Widget _fanHand(List<_Card> hand, LudoColor color) {
  final n = hand.length;
  if (n == 0) {
    return const SizedBox(height: _GameBoardState.cardH + 60);
  }

  final totalWidth = _GameBoardState.cardW + (n - 1) * (_GameBoardState.cardW - _GameBoardState.overlap);
  final totalHeight = _GameBoardState.cardH + 60;

  return SizedBox(
    height: totalHeight,
    child: Center(
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < n; i++)
              if (i != _hoverIndex) _fanCard(i, n, hand, color),

            if (_hoverIndex != null && _hoverIndex! >= 0 && _hoverIndex! < n)
              _fanCard(_hoverIndex!, n, hand, color),
          ],
        ),
      ),
    ),
  );
}


  Widget _fanCard(int index, int n, List<_Card> hand, LudoColor color) {
    if (index < 0 || index >= hand.length) return const SizedBox.shrink();
    final card = hand[index];

    final left = index * (cardW - overlap);

    final mid = (n - 1) / 2;
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
            Future.microtask(() {
             if (!mounted) return;
             if (_hoverIndex == index) setState(() => _hoverIndex = null);
           });
        },
        child: Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.1,
              child: _CardWidget(card: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _renderCardContent(card, lift, scale, opacity, angle, color, index)),
          onDragStarted: () => setState(() => _isBusy = true),
          onDragEnd: (_) => setState(() => _isBusy = false),
          child: _renderCardContent(card, lift, scale, opacity, angle, color, index),
        ),
      ),
    );
  }
  
  Widget _renderCardContent(_Card card, double lift, double scale, double opacity, double angle, LudoColor color, int index) {
      return GestureDetector(
          onTap: () => _handleCardTap(index, color),
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

class _PileWidget extends StatefulWidget {
  final String label;
  final int count;
  final bool isDiscard;

  const _PileWidget({
    required this.label,
    required this.count,
    required this.isDiscard,
  });

  @override
  State<_PileWidget> createState() => _PileWidgetState();
}

class _PileWidgetState extends State<_PileWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 140,
        height: 150,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(
            _saturationMatrix(widget.isDiscard ? 0.5 : 1.15),
          ),
          child: Stack(
            children: [
              // Deck stack (background cards)
              for (int i = 0; i < 3; i++)
                Positioned(
                  left: 10 + i * 3.0,
                  top: 10 + i * 2.0,
                  child: _deckCard(shadow: false),
                ),

              // Top card (bright + shadow)
              Positioned(
                left: 10 + 3 * 3.0,
                top: 10 + 3 * 2.0,
                child: _deckCard(
                  shadow: true,
                  hovered: _hovered,
                ),
              ),

              
              // Overlay label
              Positioned(
                left: 10 + 3 * 3.0,
                top: 10 + 3 * 2.0,
                child: SizedBox(
                  width: 110,
                  height: 130,
                  child: Center(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Count pill
              Positioned(
                right: 12,
                bottom: 12,
                child: _CounterPill(
                  label: widget.label,
                  value: widget.count,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deckCard({required bool shadow, bool hovered = false}) {
  return Container(
    width: 110,
    height: 130,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // Card back
          Image.asset(
            'assets/cards/card_back.png',
            fit: BoxFit.contain,
            width: 110,
            height: 130,
          ),

          // Hover overlay — ONLY on top card
          if (hovered)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
        ],
      ),
    ),
  );
}


  List<double> _saturationMatrix(double s) {
    final inv = 1 - s;
    final r = 0.213 * inv;
    final g = 0.715 * inv;
    final b = 0.072 * inv;

    return [
      r + s, g,     b,     0, 0,
      r,     g + s, b,     0, 0,
      r,     g,     b + s, 0, 0,
      0,     0,     0,     1, 0,
    ];
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

class _TeleportDialog extends StatefulWidget {
  const _TeleportDialog();

  @override
  State<_TeleportDialog> createState() => _TeleportDialogState();
}

class _TeleportDialogState extends State<_TeleportDialog> {
  int _value = 0; 

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2630),
      title: const Text("Teleport Distance", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        height: 120,
        child: Column(
          children: [
             Text(
                 _value > 0 ? "Forward $_value" : (_value < 0 ? "Backward ${_value.abs()}" : "Stay (0)"),
                 style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18),
             ),
             const SizedBox(height: 20),
             Slider(
                 value: _value.toDouble(),
                 min: -6,
                 max: 6,
                 divisions: 12,
                 activeColor: Colors.cyan,
                 inactiveColor: Colors.white24,
                 onChanged: (v) => setState(() => _value = v.round()),
             ),
             const Text("-6         0         +6", style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
      actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"), // Returns null
          ),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, _value),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text("Teleport", style: TextStyle(color: Colors.black)),
          )
      ],
    );
  }
}


