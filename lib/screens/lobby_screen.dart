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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
          final players = widget.service.lobbyPlayers;
          final localId = widget.service.localPlayerId;
          final isHost = widget.service.isHost;
          
          return Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            appBar: AppBar(
                title: const Text("Lobby (v1.2)"),
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
                                    final colorStr = p['color'];
                                    final isReady = p['isReady'] ?? false;
                                    final isMe = uid == localId;
                                    
                                    Color? color;
                                    if (colorStr != null) {
                                        color = _getColor(LudoColorExt.fromString(colorStr));
                                    }
                                    
                                    return ListTile(
                                        tileColor: Colors.white.withOpacity(0.05),
                                        leading: CircleAvatar(
                                            backgroundColor: color ?? Colors.grey,
                                            child: Icon(Icons.person, color: color == null ? Colors.white : Colors.black87),
                                        ),
                                        title: Text("$name ${isMe ? '(You)' : ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        const Text("Choose Your Team", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: LudoColor.values.map((c) {
                                final color = _getColor(c);
                                final isTaken = players.any((p) => p['color'] == c.toShortString() && p['uid'] != localId);
                                final isSelected = widget.service.localColor == c;
                                
                                return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: GestureDetector(
                                        onTap: isTaken ? null : () async {
                                            bool success = await widget.service.selectColor(c);
                                            if (!success && mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to select color. Try again.")));
                                            }
                                        },
                                        child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: isSelected ? 60 : 50,
                                            height: isSelected ? 60 : 50,
                                            decoration: BoxDecoration(
                                                color: isTaken ? color.withOpacity(0.2) : color,
                                                shape: BoxShape.circle,
                                                border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                                boxShadow: isSelected ? [BoxShadow(color: color, blurRadius: 12)] : null,
                                            ),
                                            child: isTaken ? const Icon(Icons.lock, color: Colors.white38) : null,
                                        ),
                                    ),
                                );
                            }).toList(),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        if (isHost)
                            SizedBox(
                                width: 200,
                                height: 56,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: players.length >= 2 ? Colors.green : Colors.grey, 
                                        foregroundColor: Colors.white
                                    ),
                                    onPressed: players.length >= 2 ? () { 
                                        // Initialize Game State (Host logic)
                                        final engine = LudoRpgEngine();
                                        final fixedColors = [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue];
                                        
                                        // Greedy Assignment Algorithm
                                        Map<LudoColor, String> colorAssignments = {};
                                        Map<String, int> playerLoad = {}; 
                                        for (var p in players) {
                                            playerLoad[p['uid']] = 0;
                                        }

                                        // 1. Respect Choices
                                        for (var c in fixedColors) {
                                            final matching = players.firstWhere((p) => p['color'] == c.toShortString(), orElse: () => {});
                                            if (matching.isNotEmpty) {
                                                colorAssignments[c] = matching['uid'];
                                                playerLoad[matching['uid']] = (playerLoad[matching['uid']] ?? 0) + 1;
                                            }
                                        }

                                        // 2. Fill Gaps (Round Robin / Min Load)
                                        for (var c in fixedColors) {
                                            if (!colorAssignments.containsKey(c)) {
                                                // Find player with min load
                                                var candidate = players[0];
                                                int minLoad = playerLoad[candidate['uid']]!;
                                                
                                                for (var p in players) {
                                                    int load = playerLoad[p['uid']]!;
                                                    if (load < minLoad) {
                                                        candidate = p;
                                                        minLoad = load;
                                                    }
                                                }
                                                
                                                // Assign
                                                colorAssignments[c] = candidate['uid'];
                                                playerLoad[candidate['uid']] = minLoad + 1;
                                            }
                                        }

                                        // 3. Build State
                                        List<LudoPlayer> gamePlayers = [];
                                        for (var c in fixedColors) {
                                            String uid = colorAssignments[c]!;
                                            final tokens = List.generate(4, (i) => LudoToken(id: '${c.toShortString()}_$i', color: c));
                                            gamePlayers.add(LudoPlayer(id: uid, color: c, tokens: tokens));
                                        }

                                        final initialState = LudoRpgGameState(players: gamePlayers);
                                        engine.initializeGame(initialState);
                                        widget.service.startGame(initialState);
                                    } : () {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need at least 2 players to start!")));
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
                         
                         if (!isHost && widget.service.roomStatus != 'playing')
                            const Text("Waiting for Host to start...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                            
                         const SizedBox(height: 20),
                         Text("DEBUG: Status=${widget.service.roomStatus} | LocalID=${localId?.substring(0,4)}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
