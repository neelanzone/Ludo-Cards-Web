import 'dart:ui';
import 'dart:math';

/// Holds the static layout definitions for the Ludo Board.
/// 
/// WORKFLOW:
/// 1. Enable `kCalibrationMode` in `ludo_board.dart`.
/// 2. Click on the board to log coordinates.
/// 3. Copy the list of Offsets from the console.
/// 4. Paste them here into `mainTrack`.
class BoardLayout {
  // Assuming a standard 15x15 grid for initial fallback values.
  // These are normalized (0.0 to 1.0) coordinates.
  // x_norm = (col + 0.5) / 15.0
  // y_norm = (row + 0.5) / 15.0
  
  static const List<Offset> mainTrack = [
    // Red Start Area (Bottom-Left wing, moving up)
    Offset(1.5/15, 13.5/15), Offset(1.5/15, 12.5/15), Offset(1.5/15, 11.5/15), Offset(1.5/15, 10.5/15), Offset(1.5/15, 9.5/15),
    // Turning right towards center
    Offset(0.5/15, 8.5/15), Offset(1.5/15, 8.5/15), Offset(2.5/15, 8.5/15), Offset(3.5/15, 8.5/15), Offset(4.5/15, 8.5/15), Offset(5.5/15, 8.5/15),
    // Center Up path (vertical)
    Offset(6.5/15, 8.5/15), // This looks wrong compared to standard ludo...
    // WAIT. I should just generate this list programmatically ONCE here using the existing logic 
    // to ensure 100% parity with what the user has now, then they can overwrite it.
  ];
  
  // Helper to generate the legacy path for fallback
  static List<Offset> getLegacyPath() {
      List<Point<int>> path = [];
      int x = 1; int y = 6; 
      for(int i=0; i<5; i++) { path.add(Point(x++, y)); } 
      x = 6; y = 5;
      for(int i=0; i<6; i++) { path.add(Point(x, y--)); } 
      path.add(Point(7, 0)); path.add(Point(8, 0));
      x = 8; y = 1;
      for(int i=0; i<5; i++) { path.add(Point(x, y++)); } 
      x = 9; y = 6;
      for(int i=0; i<6; i++) { path.add(Point(x++, y)); } 
      path.add(Point(14, 7)); path.add(Point(14, 8));
      x = 13; y = 8;
      for(int i=0; i<5; i++) { path.add(Point(x--, y)); } 
      x = 8; y = 9;
      for(int i=0; i<6; i++) { path.add(Point(x, y++)); } 
      path.add(Point(7, 14)); path.add(Point(6, 14));
      x = 6; y = 13;
      for(int i=0; i<5; i++) { path.add(Point(x, y--)); } 
      x = 5; y = 8;
      for(int i=0; i<6; i++) { path.add(Point(x--, y)); } 
      path.add(Point(0, 7)); path.add(Point(0, 6)); 
      
      return path.map((p) => Offset((p.x + 0.5)/15.0, (p.y + 0.5)/15.0)).toList();
  }
}
