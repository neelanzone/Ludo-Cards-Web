import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/multiplayer_service.dart';
import 'screens/lobby_screen.dart';
import 'screens/main_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final service = MultiplayerService();
  
  // URL Routing Logic (Web)
  String? autoJoinRoomId;
  if (Uri.base.queryParameters.containsKey('room')) {
      autoJoinRoomId = Uri.base.queryParameters['room'];
  }

  runApp(LudoRpgApp(service: service, autoJoinRoomId: autoJoinRoomId));
}

class LudoRpgApp extends StatelessWidget {
  final MultiplayerService service;
  final String? autoJoinRoomId;

  const LudoRpgApp({super.key, required this.service, this.autoJoinRoomId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, secondary: Colors.purpleAccent),
      ),
      home: _resolveHome(),
    );
  }

  Widget _resolveHome() {
      if (autoJoinRoomId != null) {
          // Attempt join
          // We can't await here in build, so we pass it to a wrapper or handle in Lobby
          // Better: Go to Lobby directly, let Lobby handle the join process or error
          // But Lobby expects to be joined. 
          // Let's us a FutureBuilder wrapper or just MainMenu with auto-action
          
          // Simple approach: MainMenu has logic? No.
          // Let's make a generic Loading/Resolver screen or just pass to MainMenu to auto-trigger?
          // Actually, let's just go to MainMenu for now, as Auth is needed.
          // Service handles Auth in joinRoom.
          
          return _AutoJoinWrapper(service: service, roomId: autoJoinRoomId!);
      }
      return MainMenu(multiplayerService: service);
  }
}

class _AutoJoinWrapper extends StatefulWidget {
    final MultiplayerService service;
    final String roomId;
    const _AutoJoinWrapper({required this.service, required this.roomId});

  @override
  State<_AutoJoinWrapper> createState() => _AutoJoinWrapperState();
}

class _AutoJoinWrapperState extends State<_AutoJoinWrapper> {
    @override
    void initState() {
        super.initState();
        _attemptJoin();
    }
    
    Future<void> _attemptJoin() async {
        try {
            await widget.service.joinRoom(widget.roomId);
            if (mounted) {
                Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => LobbyScreen(service: widget.service, roomId: widget.roomId))
                );
            }
        } catch (e) {
            if (mounted) {
                // Fallback to menu
                Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => MainMenu(multiplayerService: widget.service))
                );
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auto-join failed: $e")));
            }
        }
    }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
