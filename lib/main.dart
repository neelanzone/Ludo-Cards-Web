import 'package:flutter/material.dart';
import 'game_board.dart';

void main() {
  runApp(const LudoRpgApp());
}

class LudoRpgApp extends StatelessWidget {
  const LudoRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo RPG V0.1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          surface: Color(0xFF2C2C2C),
        ),
        useMaterial3: true,
      ),
      home: const GameBoard(),
    );
  }
}
