import 'package:flutter/material.dart';
import 'game_board.dart';

void main() => runApp(const LudoRpgApp());

class LudoRpgApp extends StatelessWidget {
  const LudoRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameBoard(),
    );
  }
}
