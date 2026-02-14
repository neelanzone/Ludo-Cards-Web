import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/models/ludo_game_state.dart' show LudoRpgGameState;
import 'package:ludo_rpg/services/multiplayer_service.dart';
import 'package:ludo_rpg/game_board.dart';
import 'package:ludo_rpg/ludo_rpg_engine.dart';

class LobbyScreen extends StatefulWidget {
  final MultiplayerService service;
  final String roomId;

  const LobbyScreen({super.key, required this.service, required this.roomId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for room status changes to navigate
    widget.service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (widget.service.roomStatus == 'playing') {
       _navigateToGame();
    }
  }

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
          final players = widget.service.lobbyPlayers;
          final localId = widget.service.localPlayerId;
          final isHost = widget.service.isHost;
          
          final lockedColors = widget.service.lockedColors;
          final tentativeColors = widget.service.tentativeColors;
          final playerReady = widget.service.playerReady;
          
          final myTentative = tentativeColors[localId];
          final myLocked = lockedColors.entries.where((e) => e.value == localId).map((e) => e.key).firstOrNull;
          final iAmReady = widget.service.iAmReady;
          
          // Can start if all players are ready and we have at least 2 players
          final canStart = players.isNotEmpty && players.length >= 2 && widget.service.allPlayersReady;

          return Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            appBar: AppBar(
                title: const Text("Lobby (v2.0)"),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                        widget.service.leaveRoom();
                        Navigator.pop(context);
                    },
                ),
            ),
            body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                    children: [
                        // Room Code
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Text("ROOM CODE: ", style: TextStyle(color: Colors.white70)),
                                    SelectableText(
                                        widget.roomId,
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                                    ),
                                    IconButton(
                                        icon: const Icon(Icons.copy, color: Colors.white70),
                                        onPressed: () {
                                            Clipboard.setData(ClipboardData(text: widget.roomId));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                                        },
                                    )
                                ],
                            ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Players List
                        Expanded(
                            child: ListView.separated(
                                itemCount: players.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                    final p = players[index];
                                    final uid = p['uid'];
                                    final name = p['name'];
                                    
                                    final isMe = uid == localId;
                                    
                                    // Determine display color (Locked > Tentative)
                                    LudoColor? displayColor;
                                    bool isLocked = false;
                                    
                                    // Check locked
                                    lockedColors.forEach((c, ownerUid) {
                                        if (ownerUid == uid) {
                                            displayColor = c;
                                            isLocked = true;
                                        }
                                    });
                                    
                                    // Check tentative if not locked
                                    if (displayColor == null && tentativeColors.containsKey(uid)) {
                                        displayColor = tentativeColors[uid];
                                    }
                                    
                                    final color = displayColor != null ? _getColor(displayColor!) : Colors.grey;
                                    final isReady = playerReady[uid] ?? false;
                                    
                                    return ListTile(
                                        tileColor: Colors.white.withOpacity(0.05),
                                        leading: CircleAvatar(
                                            backgroundColor: isLocked ? color : color.withOpacity(0.5),
                                            child: Icon(Icons.person, color: displayColor == null ? Colors.white : Colors.black87),
                                        ),
                                        title: Row(
                                          children: [
                                            Text("$name ${isMe ? '(You)' : ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            if (!isLocked && displayColor != null)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 8.0),
                                                  child: Text("(Choosing...)", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                                                ),
                                          ],
                                        ),
                                        trailing: isReady 
                                            ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                                            : const Icon(Icons.pending, color: Colors.orangeAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isMe ? const BorderSide(color: Colors.cyan, width: 2) : BorderSide.none),
                                    );
                                },
                            ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Color Selection
                        const Text("Choose Your Team (Tap to Select, Confirm to Lock)", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: LudoColor.values.map((c) {
                                final color = _getColor(c);
                                
                                // Status checks
                                final lockedOwner = lockedColors[c];
                                final isLockedBySomeone = lockedOwner != null;
                                final isLockedByMe = lockedOwner == localId;
                                
                                final tentativeOwner = tentativeColors.entries.where((e) => e.value == c).map((e) => e.key).firstOrNull;
                                final isTentativeByMe = tentativeOwner == localId;
                                
                                // Visuals
                                final isTaken = isLockedBySomeone && !isLockedByMe;
                                final isSelected = isLockedByMe || isTentativeByMe;
                                
                                return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: GestureDetector(
                                        onTap: (isTaken || iAmReady) ? null : () {
                                            HapticFeedback.selectionClick();
                                            widget.service.setTentative(c);
                                        },
                                        child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: isSelected ? 60 : 50,
                                            height: isSelected ? 60 : 50,
                                            decoration: BoxDecoration(
                                                color: isTaken 
                                                    ? color.withOpacity(0.2) 
                                                    : (isSelected ? color : color.withOpacity(0.3)),
                                                shape: BoxShape.circle,
                                                border: isSelected 
                                                    ? Border.all(color: Colors.white, width: 3) 
                                                    : (isTentativeByMe ? Border.all(color: color, width: 2, style: BorderStyle.solid) : null), // Dashed border hard in simple container
                                                boxShadow: isSelected ? [BoxShadow(color: color, blurRadius: 12)] : null,
                                            ),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    if (isLockedBySomeone)
                                                        const Icon(Icons.lock, color: Colors.white38),
                                                    if (tentativeOwner != null && !isLockedBySomeone && !isTentativeByMe)
                                                        // Show small indicator that someone else is looking at this
                                                        Container(
                                                            width: 10, height: 10,
                                                            decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
                                                        ),
                                                ],
                                            ),
                                        ),
                                    ),
                                );
                            }).toList(),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        if (!iAmReady)
                            SizedBox(
                                width: 200,
                                height: 50,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: myTentative != null ? Colors.cyan : Colors.grey.shade800,
                                        foregroundColor: Colors.white
                                    ),
                                    onPressed: (_isBusy || myTentative == null) ? null : () async {
                                        setState(() => _isBusy = true);
                                        bool success = await widget.service.confirmSelection();
                                        if (mounted) {
                                            setState(() => _isBusy = false);
                                            if (!success) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to lock color. Already taken?")));
                                            }
                                        }
                                    },
                                    child: _isBusy 
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                        : const Text("CONFIRM SELECTION"),
                                ),
                            )
                        else
                           const Text("You are Ready!", style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 24),
                        
                        if (isHost)
                            SizedBox(
                                width: 200,
                                height: 56,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: canStart ? Colors.green : Colors.grey, 
                                        foregroundColor: Colors.white
                                    ),
                                    onPressed: canStart ? () { 
                                        // Initialize Game State (Host logic)
                                        final engine = LudoRpgEngine();
                                        
                                        // Build State from Locked Colors
                                        List<LudoPlayer> gamePlayers = [];
                                        lockedColors.forEach((color, uid) {
                                            final tokens = List.generate(4, (i) => LudoToken(id: '${color.toShortString()}_$i', color: color));
                                            gamePlayers.add(LudoPlayer(id: uid, color: color, tokens: tokens));
                                        });
                                        
                                        // Sort by Turn Order (Red, Green, Yellow, Blue)
                                        gamePlayers.sort((a, b) => a.color.index.compareTo(b.color.index));

                                        final initialState = LudoRpgGameState(players: gamePlayers);
                                        engine.initializeGame(initialState);
                                        widget.service.startGame(initialState);
                                    } : () {
                                        if (players.length < 2) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need at least 2 players!")));
                                        } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wait for everyone to Confirm!")));
                                        }
                                    },
                                    child: const Text("START GAME", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                            ),
 
                        // MANUAL JOIN BUTTON (Fallback)
                        if (!isHost && widget.service.roomStatus == 'playing')
                             SizedBox(
                                width: 200,
                                height: 56,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                                    onPressed: _navigateToGame,
                                    child: const Text("ENTER GAME NOW", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                             ),
                         
                         if (!isHost && widget.service.roomStatus != 'playing' && iAmReady)
                            const Text("Waiting for Host to start...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                            
                         const SizedBox(height: 20),
                         Text("DEBUG: Status=${widget.service.roomStatus} | Locked=${lockedColors.length}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                ),
            ),
          );
      },
    );
  }
  
  void _navigateToGame() {
       Navigator.pushReplacement(
           context,
           MaterialPageRoute(builder: (_) => GameBoard(
               multiplayerService: widget.service,
               isMultiplayer: true,
           )),
       );
  }

  Color _getColor(LudoColor c) {
      switch(c) {
          case LudoColor.red: return Colors.redAccent;
          case LudoColor.green: return Colors.greenAccent;
          case LudoColor.yellow: return Colors.amberAccent;
          case LudoColor.blue: return Colors.blueAccent;
      }
  }
}
