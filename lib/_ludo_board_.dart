import 'package:flutter/material.dart';
import 'models.dart';

class LudoBoard extends StatelessWidget {
  final List<LudoPlayer> players;
  
  const LudoBoard({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: CustomPaint(
          painter: LudoBoardPainter(players: players),
        ),
      ),
    );
  }
}

class LudoBoardPainter extends CustomPainter {
  final List<LudoPlayer> players;

  LudoBoardPainter({required this.players});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cellW = w / 15;
    final double cellH = h / 15;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 1.0;

    // Background
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Draw 4 Quadrants (Bases)
    _drawBase(canvas, 0, 0, cellW * 6, cellH * 6, Colors.red, paint);
    _drawBase(canvas, w - cellW * 6, 0, cellW * 6, cellH * 6, Colors.green, paint);
    _drawBase(canvas, w - cellW * 6, h - cellH * 6, cellW * 6, cellH * 6, Colors.yellow, paint);
    _drawBase(canvas, 0, h - cellH * 6, cellW * 6, cellH * 6, Colors.blue, paint);

    // Draw Paths (The cross)
    // Vertical Strip
    _drawGrid(canvas, cellW * 6, 0, 3, 6, cellW, cellH, borderPaint);
    _drawGrid(canvas, cellW * 6, h - cellH * 6, 3, 6, cellW, cellH, borderPaint);
    
    // Horizontal Strip
    _drawGrid(canvas, 0, cellH * 6, 6, 3, cellW, cellH, borderPaint);
    _drawGrid(canvas, w - cellW * 6, cellH * 6, 6, 3, cellW, cellH, borderPaint);

    // Colored Paths
    // Red Start
    paint.color = Colors.red;
    canvas.drawRect(Rect.fromLTWH(cellW * 1, cellH * 6, cellW, cellH), paint);
    for (int i=1; i<6; i++) {
         canvas.drawRect(Rect.fromLTWH(cellW * i, cellH * 7, cellW, cellH), paint);
    }
    
    // Green Start
    paint.color = Colors.green;
    canvas.drawRect(Rect.fromLTWH(cellW * 8, cellH * 1, cellW, cellH), paint);
    for (int i=1; i<6; i++) {
        canvas.drawRect(Rect.fromLTWH(cellW * 7, cellH * i, cellW, cellH), paint);
    }

    // Yellow Start
    paint.color = Colors.yellow;
    canvas.drawRect(Rect.fromLTWH(cellW * 13, cellH * 8, cellW, cellH), paint);
    for (int i=9; i<14; i++) {
        canvas.drawRect(Rect.fromLTWH(cellW * i, cellH * 7, cellW, cellH), paint);
    }

    // Blue Start
    paint.color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(cellW * 6, cellH * 13, cellW, cellH), paint);
    for (int i=9; i<14; i++) {
        canvas.drawRect(Rect.fromLTWH(cellW * 7, cellH * i, cellW, cellH), paint);
    }
    
    // Center Home
    final Path centerPath = Path();
    centerPath.moveTo(cellW * 6, cellH * 6);
    centerPath.lineTo(cellW * 9, cellH * 6);
    centerPath.lineTo(cellW * 9, cellH * 9);
    centerPath.lineTo(cellW * 6, cellH * 9);
    centerPath.close();
    
    paint.color = Colors.black12; // Placeholder for center
    canvas.drawPath(centerPath, paint);
    canvas.drawPath(centerPath, borderPaint);

    // Center Triangles
    paint.color = Colors.red;
    Path redTri = Path()..moveTo(cellW*6, cellH*6)..lineTo(cellW*6, cellH*9)..lineTo(cellW*7.5, cellH*7.5)..close();
    canvas.drawPath(redTri, paint);

    paint.color = Colors.green;
    Path greenTri = Path()..moveTo(cellW*6, cellH*6)..lineTo(cellW*9, cellH*6)..lineTo(cellW*7.5, cellH*7.5)..close();
    canvas.drawPath(greenTri, paint);
    
    paint.color = Colors.yellow;
    Path yellowTri = Path()..moveTo(cellW*9, cellH*6)..lineTo(cellW*9, cellH*9)..lineTo(cellW*7.5, cellH*7.5)..close();
    canvas.drawPath(yellowTri, paint);

    paint.color = Colors.blue;
    Path blueTri = Path()..moveTo(cellW*6, cellH*9)..lineTo(cellW*9, cellH*9)..lineTo(cellW*7.5, cellH*7.5)..close();
    canvas.drawPath(blueTri, paint);

    // Draw Tokens
    for (var player in players) {
      for (var token in player.tokens) {
          _drawToken(canvas, token, cellW, cellH);
      }
    }
  }

  void _drawToken(Canvas canvas, LudoToken token, double cellW, double cellH) {
     Offset? pos = _getTokenCoordinates(token, cellW, cellH);
     if (pos != null) {
        final paint = Paint()
           ..color = Colors.black
           ..style = PaintingStyle.fill;
        
        // Shadow/Outline
        canvas.drawCircle(pos, cellW * 0.35, paint);
        
        // Inner Color
        paint.color = _getColor(token.color);
        canvas.drawCircle(pos, cellW * 0.3, paint);

        // White dot for style
        paint.color = Colors.white;
         canvas.drawCircle(pos, cellW * 0.1, paint);
     }
  }

  Offset? _getTokenCoordinates(LudoToken token, double cw, double ch) {
      // 1. Home Base Positions (-1)
      if (token.position == -1) {
          // Determine which of the 4 slots in base based on token ID suffix or index
          // For simplicity, we parse the ID to get an index (e.g. "red_0")
          int index = int.tryParse(token.id.split('_').last) ?? 0;
          double baseX = 0, baseY = 0;
          
          switch(token.color) {
              case LudoColor.red: baseX=0; baseY=0; break;
              case LudoColor.green: baseX=cw*9; baseY=0; break;
              case LudoColor.yellow: baseX=cw*9; baseY=ch*9; break;
              case LudoColor.blue: baseX=0; baseY=ch*9; break;
          }
          
          // Offsets for the 4 circles
          double offX = (index % 2 == 0) ? cw * 2.5 : cw * 4.5; // Adjusted visually
          double offY = (index < 2) ? ch * 2.5 : ch * 4.5; 
          
          // Actually, let's use the explicit math from _drawBase
          // _drawBase uses logic: x + w * 0.15 + w*0.175 etc..
          // w = cw * 6
          
          double w = cw * 6;
          
          double localX = 0;
          double localY = 0;
          // TL, TR, BL, BR
          if (index == 0) { localX = w * 0.325; localY = w * 0.325; }
          else if (index == 1) { localX = w * 0.675; localY = w * 0.325; }
          else if (index == 2) { localX = w * 0.325; localY = w * 0.675; }
          else { localX = w * 0.675; localY = w * 0.675; }

          return Offset(baseX + localX, baseY + localY);
      }
      
      // 2. Main Track (0-51)
      if (token.position >= 0 && token.position < 52) {
          // Coordinates map ... this is tedious.
          // Let's define the path of 52 cells starting from Red's start (1, 6)
          // 0 -> (1,6)
          // 1 -> (2,6) ... (5,6)
          // Then up (6,5) ... (6,0)
          // Then right (7,0) ? No, that's top middle.
          
          List<Point<int>> path = _getMainTrackPath();
          // Adjust for player offset?
          // The 'position' in Token should be absolute (0-51 relative to board) or relative to player?
          // Let's say relative to player start.
          // 0 is the start cell for that color.
          
          int startOffset = 0;
          switch (token.color) {
             case LudoColor.red: startOffset = 0; break;
             case LudoColor.green: startOffset = 13; break;
             case LudoColor.yellow: startOffset = 26; break;
             case LudoColor.blue: startOffset = 39; break;
          }
          
          int absPos = (token.position + startOffset) % 52;
          Point<int> p = path[absPos];
          return Offset((p.x + 0.5) * cw, (p.y + 0.5) * ch);
      }
      
      // 3. Home Stretch (52-57)
       if (token.position >= 52) {
           // .. Logic for home column ..
           // Red: (1,7) -> (5,7)
           // Green: (7,1) -> (7,5)
           // Yellow: (13,7) -> (9,7)
           // Blue: (7,13) -> (7,9)
           
           int stepsIn = token.position - 51; // 1 to 5
           if (stepsIn > 5) stepsIn = 6; // Center
           
           int x=0, y=0;
           switch(token.color) {
               case LudoColor.red: 
                   x = stepsIn; y = 7; 
                   if (stepsIn == 6) { x=6; y=7;} // Triangle part? or center box?
                   break;
               case LudoColor.green: 
                   x = 7; y = stepsIn; 
                   break;
               case LudoColor.yellow:
                   x = 14 - stepsIn; y = 7;
                   break;
               case LudoColor.blue:
                   x = 7; y = 14 - stepsIn;
                   break;
           }
           return Offset((x + 0.5) * cw, (y + 0.5) * ch);
       }

      return null;
  }
  
  List<Point<int>> _getMainTrackPath() {
      List<Point<int>> path = [];
      int x = 1; 
      int y = 6; // Start for Red

      // 12 Segments to form the loop
      final segments = [
        _PathSegment(1, 0, 5),   // Right 5
        _PathSegment(1, -1, 1),  // Up-Right diag (virtual) -> actually just jump to (6,5)
        _PathSegment(0, -1, 5),  // Up 5
        _PathSegment(1, 0, 2),   // Right 2 (Top Turn)
        _PathSegment(0, 1, 5),   // Down 5
        _PathSegment(1, 1, 1),   // Down-Right diag -> jump to (9,6)
        _PathSegment(1, 0, 5),   // Right 5
        _PathSegment(0, 1, 2),   // Down 2 (Right Turn)
        _PathSegment(-1, 0, 5),  // Left 5
        _PathSegment(-1, 1, 1),  // Down-Left diag -> jump to (8,9)
        _PathSegment(0, 1, 5),   // Down 5
        _PathSegment(-1, 0, 2),  // Left 2 (Bottom Turn)
        _PathSegment(0, -1, 5),  // Up 5
        _PathSegment(-1, -1, 1), // Up-Left diag -> jump to (6,8)
        _PathSegment(-1, 0, 5),  // Left 5
        _PathSegment(0, -1, 2),  // Up 2 (Left Turn)
      ];
      
      // My previous analysis:
      // Seg 1: (1,6) -> (5,6) [Right, 5]
      // Seg 2: (6,5) -> (6,0) [Up, 6]  <-- Wait, (6,5) is x+1, y-1 from (5,6).
      
      // Let's simplified specific points list or a cleaner generator.
      // The user suggested: "move n steps in direction, turn, repeat".
      
      // Let's just hardcode the turns strictly.
      
      void addLine(int dx, int dy, int count) {
          for(int i=0; i<count; i++) {
              path.add(Point(x, y));
              x += dx;
              y += dy;
          }
      }
      
      // Red Start Arm
      addLine(1, 0, 5); // (1,6) -> (5,6)
      x = 6; y = 5;     // Jump diag
      addLine(0, -1, 5); // (6,5) -> (6,1)
      addLine(0, -1, 1); // (6,0) -> Extra step to top
      
      x = 7; y = 0; // Top Left Turn
      addLine(1, 0, 1); // (7,0)
      x = 8; y = 0; // Top Right
      addLine(0, 1, 1); // (8,0) -> (8,1) ?? No.
      
      // Let's restart with the 4x13 approach the user mentioned.
      // 13 cells per quadrant.
      // Q1 (Red to Green transition):
      // 5 Right, 6 Up, 2 Across? No.
      
      // Standard: 
      // 5 horizontal, 1 diag-ish, 5 vertical. Top 3.
      
      // Reset logic.
      path.clear();
      x = 1; y = 6;
      
      // 1. Red straight
      for(int i=0; i<5; i++) { path.add(Point(x++, y)); } // (1,6)..(5,6)
      
      // 2. Up vertical
      x = 6; y = 5;
      for(int i=0; i<6; i++) { path.add(Point(x, y--)); } // (6,5)..(6,0)
      
      // 3. Top turn
      path.add(Point(7, 0));
      path.add(Point(8, 0));
      
      // 4. Down vertical
      x = 8; y = 1;
      for(int i=0; i<5; i++) { path.add(Point(x, y++)); } // (8,1)..(8,5)
      
      // 5. Right horizontal
      x = 9; y = 6;
      for(int i=0; i<6; i++) { path.add(Point(x++, y)); } // (9,6)..(14,6)
      
      // 6. Right turn
      path.add(Point(14, 7));
      path.add(Point(14, 8));
      
      // 7. Left horizontal
      x = 13; y = 8;
      for(int i=0; i<5; i++) { path.add(Point(x--, y)); } // (13,8)..(9,8)
      
      // 8. Down vertical
      x = 8; y = 9;
      for(int i=0; i<6; i++) { path.add(Point(x, y++)); } // (8,9)..(8,14)
      
      // 9. Bottom turn
      path.add(Point(7, 14));
      path.add(Point(6, 14));
      
      // 10. Up vertical
      x = 6; y = 13;
      for(int i=0; i<5; i++) { path.add(Point(x, y--)); } // (6,13)..(6,9)

      // 11. Left horizontal
      x = 5; y = 8;
      for(int i=0; i<6; i++) { path.add(Point(x--, y)); } // (5,8)..(0,8)
      
      // 12. Left turn
      path.add(Point(0, 7));
      path.add(Point(0, 6)); // End
      
      return path;
  }
  

  
  Color _getColor(LudoColor c) {
      switch(c) {
          case LudoColor.red: return Colors.red;
          case LudoColor.green: return Colors.green;
          case LudoColor.yellow: return Colors.amber; // Contrast
          case LudoColor.blue: return Colors.blue;
      }
  }

  void _drawBase(Canvas canvas, double x, double y, double w, double h, Color color, Paint paint) {
    paint.color = color;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    
    // Inner white box
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(x + w * 0.15, y + h * 0.15, w * 0.7, h * 0.7), paint);
    
    // 4 Token circles
    paint.color = color;
    double circleSize = w * 0.2; // space for circle
    double r = circleSize * 0.35;
    
    // Top Left
    canvas.drawCircle(Offset(x + w * 0.15 + w*0.175, y + h * 0.15 + h*0.175), r, paint);
    // Top Right
    canvas.drawCircle(Offset(x + w * 0.85 - w*0.175, y + h * 0.15 + h*0.175), r, paint);
    // Bottom Left
    canvas.drawCircle(Offset(x + w * 0.15 + w*0.175, y + h * 0.85 - h*0.175), r, paint);
    // Bottom Right
    canvas.drawCircle(Offset(x + w * 0.85 - w*0.175, y + h * 0.85 - h*0.175), r, paint);
  }

  void _drawGrid(Canvas canvas, double x, double y, int cols, int rows, double cw, double ch, Paint borderPaint) {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
         canvas.drawRect(Rect.fromLTWH(x + c * cw, y + r * ch, cw, ch), borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) => true; // Always repaint for now
}

