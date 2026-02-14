import 'package:flutter/material.dart';
import 'package:ludo_rpg/game_board.dart';
import 'package:ludo_rpg/services/multiplayer_service.dart';
import 'package:ludo_rpg/screens/lobby_screen.dart';
import 'package:ludo_rpg/screens/main_menu_screen.dart'; // Import the new screen

class MainMenu extends StatelessWidget {
  final MultiplayerService multiplayerService;

  const MainMenu({super.key, required this.multiplayerService});

  @override
  Widget build(BuildContext context) {
    // Wrap with Scaffold/Material to ensure overlay context if needed by legacy dialogs,
    // but MainMenuScreen also has Scaffold.
    // We can just return MainMenuScreen and pass callbacks.
    return MainMenuScreen(
      onPlayLocal: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameBoard()),
        );
      },
      onCreateOnlineRoom: () async {
        try {
          // Show loading feedback or just hope it's fast? 
          // The new UI doesn't have a loading state for creating room, 
          // but we can add safeguards.
          // For now, keep it simple as originally designed.
          // Ideally we might want to show a spinner. 
          // But the previous implementation didn't have a spinner for create.
          // We can add a simple snackbar or overlay.
          
          final roomId = await multiplayerService.createRoom();
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LobbyScreen(service: multiplayerService, roomId: roomId)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        }
      },
      onJoinOnlineRoom: () {
        _showJoinDialog(context);
      },
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    // Use StatefulBuilder to handle dialog state
    showDialog(context: context, builder: (context) {
      bool isJoining = false;
      String? errorMessage;
      
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C), // Match theme vaguely
            title: const Text("Enter Room ID", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller, 
                  decoration: const InputDecoration(
                    hintText: "ABCD12",
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !isJoining,
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                if (isJoining)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              if (!isJoining)
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Cancel"),
                ),
              if (!isJoining)
                ElevatedButton(
                  onPressed: () async {
                    final roomId = controller.text.trim().toUpperCase();
                    if (roomId.isEmpty) return;
                    
                    setState(() {
                      isJoining = true;
                      errorMessage = null;
                    });
                    
                    try {
                      await multiplayerService.joinRoom(roomId);
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LobbyScreen(service: multiplayerService, roomId: roomId)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() {
                          isJoining = false;
                          errorMessage = "Join failed: $e";
                        });
                      }
                    }
                  }, 
                  child: const Text("Join"),
                ),
            ],
          );
        }
      );
    });
  }
}
