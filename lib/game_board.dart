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
      _engine.drawCard(_ludo, _ludo.currentPlayer.color);
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
        _engine.drawCard(_ludo, _ludo.currentPlayer.color);
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
  
  // New Targeting State
  LudoToken? _swapFirst;
  LudoToken? _swapSecond;
  
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

  // Multi-Player Card State (Old manual maps removed)
  // New Engine-Authoritative State is in _ludo (sharedDrawPile, sharedDiscardPile, hands)

  // Cache UI Models (Image assets etc) by Instance ID
  final Map<String, _Card> _cardAssets = {};

  // Accessors for CURRENT player (to minimize refactor noise)
  List<String> get _handIds => _ludo.hands[_ludo.currentPlayer.color]!;
  List<_Card> get _hand => _handIds.map((id) => _getCard(id)).toList();
  
  // Helpers
  _Card _getCard(String instanceId) {
      if (_cardAssets.containsKey(instanceId)) return _cardAssets[instanceId]!;
      
      // Parse Template ID (Format: TEMPLATE_UUID)
      final parts = instanceId.split('_');
      final templateId = parts[0];
      final template = CardLibrary.getById(templateId);
      
      if (template == null) {
          // Fallback
          return _Card(id: instanceId, templateId: "Unknown", title: "Unknown", type: _CardType.manipulation, imageAsset: "assets/cards/back.png");
      }
      
      final card = _Card(
          id: instanceId,
          templateId: templateId,
          title: template.name,
          type: _mapEffectToVisualType(template.effectType), 
          imageAsset: "assets/cards/${templateId}.png" // Assumes asset names match IDs
      );
      _cardAssets[instanceId] = card;
      return card;
  }

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

    // Initialize Decks and Hands via Engine
    _engine.initializeGame(_ludo);
  }

  // Obsolete _generateDeck removed.
  
  _CardType _mapEffectToVisualType(CardEffectType type) {
      if (type.toString().contains("Attack") || type == CardEffectType.laser) return _CardType.attack;
      if (type.toString().contains("Shield") || type == CardEffectType.cure) return _CardType.defense;
      if (type.toString().contains("Move") || type == CardEffectType.teleport || type == CardEffectType.swapPos) return _CardType.movement;
      return _CardType.manipulation;
  }
  
  // Obsolete _drawFromSpecific removed.

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
      if (index == 0 && (_ludo.dice.a?.used ?? true)) return;
      if (index == 1 && (_ludo.dice.b?.used ?? true)) return;

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
          _visualA = _ludo.dice.a!.value;
          _visualB = _ludo.dice.b!.value;
      });
      await Future.delayed(Duration(milliseconds: delays.last));
      
      // Unlock
      if (!mounted) return;
      setState(() {
          _isRolling = false;
      });
  }

  void _syncDiceVisuals() {
    if (_ludo.dice.a != null) _visualA = _ludo.dice.a!.value;
    if (_ludo.dice.b != null) _visualB = _ludo.dice.b!.value;
  }

  Future<int?> _pickDieToDouble() async {
      // Only allow choosing dice that exist and are unused
      final aOk = _ludo.dice.a != null && !_ludo.dice.a!.used;
      final bOk = _ludo.dice.b != null && !_ludo.dice.b!.used;

      return showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Double which die?"),
          content: const Text("Choose the die to double."),
          actions: [
            TextButton(
              onPressed: aOk ? () => Navigator.pop(context, 0) : null,
              child: const Text("Die A"),
            ),
            TextButton(
              onPressed: bOk ? () => Navigator.pop(context, 1) : null,
              child: const Text("Die B"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
          ],
        ),
      );
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
  // _draw() removed; use _engine.drawCard() instead

  Future<void> _handleTokenTap(LudoToken token) async {
      if (_ludo.phase == TurnPhase.ended) return; 
      
      // Allow opponent selection ONLY in targeting phase
      if (_ludo.phase != TurnPhase.selectingTarget && token.color != _ludo.currentPlayer.color) return;

      // Check for Target Selection Resolution
      if (_ludo.phase == TurnPhase.selectingTarget) {
          final cardId = _ludo.activeCardId;
          final handIndex = _pendingCardHandIndex;
          if (cardId == null || handIndex == null) return;

          final template = CardLibrary.getById(cardId);
          if (template == null) return;
          
          // SPECIAL: Swap Mechanic (Select 2 targets)
          if (template.effectType == CardEffectType.swapPos) {
              if (_swapFirst == null) {
                  // 1. Select First Token
                  setState(() => _swapFirst = token);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select second token to swap with..."), duration: Duration(milliseconds: 1000)));
                  return;
              } else if (_swapSecond == null) {
                  // 2. Select Second Token
                  // Prevent selecting same token
                  if (token.id == _swapFirst!.id) return;
                  
                  setState(() => _swapSecond = token);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap AGAIN to confirm swap..."), duration: Duration(milliseconds: 1000)));
                  return; 
              } else {
                  // 3. Confirm (Must tap second token again)
                  if (token.id != _swapSecond!.id) {
                      // Changed mind? Select as new second?
                      setState(() => _swapSecond = token);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap AGAIN to confirm swap..."), duration: Duration(milliseconds: 1000)));
                      return;
                  }
                  
                  // EXECUTE SWAP
                  final res = _engine.playCard(gs: _ludo, card: template, target: [_swapFirst!, _swapSecond!]);
                  
                  setState(() {
                      _ludo.phase = TurnPhase.awaitAction;
                      _ludo.activeCardId = null;
                      _pendingCardHandIndex = null;
                      _swapFirst = null;
                      _swapSecond = null;
                  });
                  
                  if (res.success) {
                      await _discardCard(handIndex); // discardCard is async
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Swapped positions!"), duration: const Duration(milliseconds: 800)));
                  } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Swap failed!"), duration: const Duration(milliseconds: 800)));
                  }
                  return;
              }
          }
          
          // SPECIAL: Teleport (Target -> Distance)
          if (template.effectType == CardEffectType.teleport) {
              if (token.color != _ludo.currentPlayer.color) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Must teleport YOUR token!"), duration: Duration(milliseconds: 800)));
                   return;
              }
              
              // 1. Show Dialog
              final distance = await showDialog<int?>(
                  context: context,
                  builder: (context) => const _TeleportDialog(),
              );
              
              if (distance == null) return; // Cancelled
              
              // 2. Execute
              final res = _engine.playCard(
                  gs: _ludo, 
                  card: template, 
                  target: token, 
                  overrideValue: distance
              );
              
              setState(() {
                _ludo.phase = TurnPhase.awaitAction;
                _ludo.activeCardId = null;
                _pendingCardHandIndex = null;
                 // Clear any temp state if needed
              });

              if (res.success) {
                await _discardCard(handIndex);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Teleported $distance tiles!"), duration: const Duration(milliseconds: 800)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message ?? "Teleport failed."), duration: const Duration(milliseconds: 800)),
                );
              }
              return;
          }

          // Normal Single Target Logic
          // Check if targeting opponent is allowed/required
          if (template.targetType == TargetType.tokenEnemy && token.color == _ludo.currentPlayer.color) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Must select an Enemy token!"), duration: Duration(milliseconds: 800)));
               return;
          }
          if (template.targetType == TargetType.tokenSelf && token.color != _ludo.currentPlayer.color) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Must select YOUR token!"), duration: Duration(milliseconds: 800)));
               return;
          }

          // Attempt to play card on this token target
          final res = _engine.playCard(gs: _ludo, card: template, target: token);
          
          setState(() {
            _ludo.phase = TurnPhase.awaitAction;
            _ludo.activeCardId = null;
            _pendingCardHandIndex = null;
          });

          if (res.success) {
            _discardCard(handIndex);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Played ${template.name}!"), duration: const Duration(milliseconds: 800)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res.message ?? "Card failed (invalid target/state)."), duration: const Duration(milliseconds: 800)),
            );
          }
          return;
      }

      // 1. Try Spawn (Priority, allowed in awaitRoll too)
      if (token.isInBase) {
           setState(() {
               var res = _engine.spawnFromBase(_ludo, token);
               if (res.success) {
                  _selectedTokenId = null; 
               } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Spawn failed"), duration: const Duration(milliseconds: 800)));
               }
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
              var result = _engine.moveToken(gs: _ludo, token: token, useA: useA, useB: useB);
              if (result.success) {
                  // Move successful!
                  _selectedTokenId = null;
                  _selectedDiceIndices.clear();
                  
                  if (result.events.contains("TOKEN_KILLED")) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enemy Token Killed!"), backgroundColor: Colors.redAccent));
                  } else if (result.events.contains("TOKEN_FINISHED")) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token Finished!"), backgroundColor: Colors.amber));
                  }

              } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(result.message ?? "Invalid Move!"), duration: const Duration(milliseconds: 800))
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
      if (_isBusy) return; 
      final color = _ludo.currentPlayer.color;
      final handIds = _ludo.hands[color]!;
      
      if (index < 0 || index >= handIds.length) return;

      setState(() {
        _isBusy = true;
        _animatingSlotIndex = index;
        _isDiscarding = true;
      });

      // Shake ONLY discard pile
      _deckShakeController.forward(from: 0.0);

      await Future.delayed(animDuration);

      final cardId = handIds[index];

      setState(() {
        _engine.discardCard(_ludo, color, cardId); // Engine handles logic
        _isDiscarding = false;
        _hoverIndex = null;
      });

      await Future.delayed(animDuration);

      setState(() {
        _animatingSlotIndex = null;
        _isBusy = false;
      });
  }

  Future<void> _handleCardTap(int index, LudoColor color) async {
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

    if (template.effectType == CardEffectType.doubleDie) {
         if (_ludo.phase != TurnPhase.awaitAction) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roll dice before using Double It.")));
            return;
         }
         
         final pick = await _pickDieToDouble();
         if (pick == null) return;
         
         final res = _engine.playCard(gs: _ludo, card: template, dieIndex: pick);
         if (res.success) {
             await _discardCard(index);
             setState(() {
                 _syncDiceVisuals();
                 _selectedDiceIndices.clear();
                 _selectedTokenId = null;
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Played ${template.name}!"), duration: const Duration(milliseconds: 800)));
         } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Failed to double die."), duration: const Duration(milliseconds: 800)));
         }

    } else if (template.effectType == CardEffectType.doubleBoth) {
         if (_ludo.phase != TurnPhase.awaitAction) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roll dice before using Double It 2x.")));
            return;
         }
         
         final res = _engine.playCard(gs: _ludo, card: template);
         if (res.success) {
             await _discardCard(index);
             setState(() {
                 _syncDiceVisuals();
                 _selectedDiceIndices.clear();
                 _selectedTokenId = null;
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Applied Double Both!"), duration: const Duration(milliseconds: 800)));
         } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Failed to double dice."), duration: const Duration(milliseconds: 800)));
         }
         
    } else if (template.effectType == CardEffectType.reroll) {
         if (_ludo.phase != TurnPhase.awaitAction) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roll dice first.")));
            return;
         }

         // Single Reroll requires picking a die
         final pick = await _pickDieToDouble(); // Reuse picker (A/B)
         if (pick == null) return;

         final res = _engine.playCard(gs: _ludo, card: template, dieIndex: pick);
         if (res.success) {
             await _discardCard(index);
             setState(() {
                 _syncDiceVisuals();
                 _selectedDiceIndices.clear();
                 _selectedTokenId = null;
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rerolled Die!"), duration: const Duration(milliseconds: 800)));
         } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Reroll failed."), duration: const Duration(milliseconds: 800)));
         }

    } else if (template.effectType == CardEffectType.reroll2x) {
         if (_ludo.phase != TurnPhase.awaitAction) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roll dice first.")));
            return;
         }

         final res = _engine.playCard(gs: _ludo, card: template);
         if (res.success) {
             await _discardCard(index);
             setState(() {
                 _syncDiceVisuals();
                 _selectedDiceIndices.clear();
                 _selectedTokenId = null;
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rerolled Both!"), duration: const Duration(milliseconds: 800)));
         } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Reroll failed."), duration: const Duration(milliseconds: 800)));
         }

    } else if (template.targetType == TargetType.none) {
        // Instant Cast
        var res = _engine.playCard(gs: _ludo, card: template, target: null);
        
        // Handle Pending Choice (e.g. Dumpster Dive)
        if (res.success && res.choice != null) {
             if (res.choice!.type == PendingChoiceType.dumpsterPickOne) {
                 final options = res.choice!.options.map((id) => _getCard(id)).toList(); // _getCard caches
                 
                 // Show Dialog
                 final pickedId = await showDialog<String>(
                     context: context, 
                     barrierDismissible: false,
                     builder: (_) => _DumpsterDialog(options: options)
                 );
                 
                 if (pickedId != null) {
                     final resolveRes = _engine.resolveChoice(_ludo, pickedId);
                     if (resolveRes.success) {
                         // Discard the Dumpster Dive card (consumes action)
                         await _discardCard(index); 
                         setState(() {
                             _ludo.activeCardId = null;
                             _pendingCardHandIndex = null;
                         });
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card Recovered!"), duration: Duration(milliseconds: 800)));
                     } else {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resolveRes.message ?? "Failed to recover.")));
                     }
                 } else {
                     // Cancelled -> Revert?
                     // Ideally we revert the 'needsChoice' state. 
                     // For MVP, if they cancel, we just reset pendingChoice and do nothing (card stays in hand).
                     setState(() {
                         _ludo.pendingChoice = null; 
                         _ludo.activeCardId = null;
                         _pendingCardHandIndex = null;
                     });
                 }
             }
             return;
        }

        if (res.success) {
            _discardCard(index);
            // Clear selections on success (especially for Restart Turn)
            setState(() {
                _syncDiceVisuals(); // Sync in case of Modify Roll
                _selectedDiceIndices.clear();
                _selectedTokenId = null;
                _visualA = 4;
                _visualB = 4;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Played ${template.name}!"), duration: const Duration(milliseconds: 800)));
        } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? "Failed to play card"), duration: const Duration(milliseconds: 800)));
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
      body: Stack(
        children: [
          SafeArea(
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
                                        child: _PileWidget(label: 'Draw', count: _ludo.sharedDrawPile.length, isDiscard: false),
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
                                                       color: (_ludo.dice.a?.used ?? false) ? Colors.grey : null,
                                                       isDoubled: _ludo.dice.a?.doubled ?? false,
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
                                                       color: (_ludo.dice.b?.used ?? false) ? Colors.grey : null,
                                                       isDoubled: _ludo.dice.b?.doubled ?? false,
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
                                                        count: _ludo.sharedDiscardPile.length, 
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
      
      // Victory Overlay
      if (_ludo.winner != null)
        Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${_ludo.winner.toString().split('.').last.toUpperCase()} WINS!",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700), // Gold
                    shadows: [Shadow(blurRadius: 10, color: Colors.white)],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () {
                     setState(() {
                         _engine.resetGame(_ludo);
                     });
                  },
                  child: const Text("PLAY AGAIN", style: TextStyle(fontSize: 20, color: Colors.black)),
                )
              ],
            ),
          ),
        ),
     ],
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
               if ((_ludo.dice.a?.used ?? false) || (_ludo.dice.b?.used ?? false)) {
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


class _DumpsterDialog extends StatelessWidget {
  final List<_Card> options;

  const _DumpsterDialog({required this.options});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2630),
      title: const Text("Pick a Card to Recover", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 200, // Adjust height as needed
        child: options.isEmpty 
            ? const Center(child: Text("No cards found.", style: TextStyle(color: Colors.white54)))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((card) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, card.id),
                        child: Column(
                          children: [
                             _CardWidget(card: card),
                             const SizedBox(height: 8),
                             Text(card.title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
