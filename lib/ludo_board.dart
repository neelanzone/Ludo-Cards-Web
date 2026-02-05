import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'models.dart';
import 'ludo_rpg_engine.dart'; 
import 'board_layout.dart';

// TUNING PARAMETERS
const double kBoardPaddingFactor = 0.044; // ~4.4% padding for rocky border
const bool kShowDebugGrid = false; 
const bool kCalibrationMode = false; // Set to TRUE to record coordinates by clicking

class LudoBoard extends StatefulWidget {
  final List<LudoPlayer> players;
  final LudoRpgEngine engine; 
  final Function(LudoToken)? onTokenTap;
  final LudoColor activeColor; 
  final String? selectedTokenId; // Highlight this token

  const LudoBoard({
    super.key, 
    required this.players, 
    required this.engine,
    required this.activeColor,
    this.onTokenTap,
    this.selectedTokenId,
  });

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<LudoBoard> {
  ui.Image? _boardImage;
  bool _isLoading = true;
  double _turns = 0.0;

  double _getRotationForColor(LudoColor c) {
      switch(c) {
          case LudoColor.blue: return 0.0;
          case LudoColor.red: return -0.25;
          case LudoColor.green: return -0.50;
          case LudoColor.yellow: return -0.75;
      }
  }

  @override
  void initState() {
    super.initState();
    _turns = _getRotationForColor(widget.activeColor);
    _loadAssets();
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadAssets();
  }

  @override
  void didUpdateWidget(LudoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeColor != oldWidget.activeColor) {
        double target = _getRotationForColor(widget.activeColor);
        double diff = target - _turns;
        // Shortest path normalization
        _turns += (diff - diff.round());
    }
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final ByteData data = await rootBundle.load('assets/board.png');
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _boardImage = fi.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading board image: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine rotation turns based on active player to bring them to Bottom-Left.
    // Default: Blue is Bottom-Left (0 turns).
    // Red (Top-Left) -> Needs -0.25 turn (CCW 90) to reach Bottom-Left.
    // Green (Top-Right) -> Needs -0.50 turn.
    // Yellow (Bottom-Right) -> Needs -0.75 turn.
    


    // Fix for Yellow (-0.75) -> Blue (0) long spin:
    // This simple logic will spin back 270 degrees.
    // For MVP, straightforward implementation is acceptable.

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black, 
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedRotation(
              turns: _turns,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutBack,
              child: GestureDetector(
                onTapUp: (details) {
                   _handleTap(details.localPosition, constraints.maxWidth);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: LudoBoardPainter(
                      players: widget.players, 
                      engine: widget.engine, 
                      activeColor: widget.activeColor,
                      boardImage: _boardImage,
                      selectedTokenId: widget.selectedTokenId,
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  void _handleTap(Offset localPos, double totalWidth) {
    if (kCalibrationMode) {
        // Calibration Logic: Print normalized coordinates
        double nx = localPos.dx / totalWidth;
        double ny = localPos.dy / totalWidth;
        debugPrint("Offset(${nx.toStringAsFixed(4)}, ${ny.toStringAsFixed(4)}), // Recorded Click");
        return; // Consume tap
    }

    if (widget.onTokenTap == null) return;
    
    // Apply Padding Logic logic
    double padding = totalWidth * kBoardPaddingFactor;
    double playableWidth = totalWidth - (2 * padding);
    double cellW = playableWidth / 15;
    double cellH = playableWidth / 15; 

    LudoToken? bestMatch;

    for (var player in widget.players) {
      for (var token in player.tokens) {
         if (token.isDead) continue;
         // _getTokenCoordinates handles the padding shift internally
         Offset? pos = _getTokenCoordinates(token, cellW, cellH, widget.engine, padding);
         if (pos != null) {
            // Hit box slightly generous (0.7 of a cell)
            if ((pos - localPos).distance < cellW * 0.7) { 
               if (token.color == widget.activeColor) {
                   widget.onTokenTap!(token);
                   return;
               }
               bestMatch = token;
            }
         }
      }
    }
    
    if (bestMatch != null) {
        widget.onTokenTap!(bestMatch);
    }
  }

  Offset? _getTokenCoordinates(LudoToken token, double cw, double ch, LudoRpgEngine engine, double padding) {
      // Offset all calculations by 'padding'
      Offset applyPadding(Offset local) => local + Offset(padding, padding);

      if (token.isInBase) {
          int index = int.tryParse(token.id.split('_').last) ?? 0;
          double baseX = 0, baseY = 0;
          switch(token.color) {
              case LudoColor.red: baseX=0; baseY=0; break;
              case LudoColor.green: baseX=cw*9; baseY=0; break;
              case LudoColor.yellow: baseX=cw*9; baseY=ch*9; break;
              case LudoColor.blue: baseX=0; baseY=ch*9; break;
          }
          double w = cw * 6;
          // Centered offsets: 2.0 and 4.0 grid units (Space of 1 unit between them 2->3->4)
          // Base is 6x6. Center is 3,3. 2 and 4 are symmetric around 3.
          // Centered offsets: 2.5 and 3.5 grid units (Tight cluster)
          // Base is 6x6. Center is 3,3.
          double localX=0, localY=0;
          if (index == 0) { localX = w * (2.5/6.0); localY = w * (2.5/6.0); }
          else if (index == 1) { localX = w * (3.5/6.0); localY = w * (2.5/6.0); }
          else if (index == 2) { localX = w * (2.5/6.0); localY = w * (3.5/6.0); }
          else { localX = w * (3.5/6.0); localY = w * (3.5/6.0); }
          return applyPadding(Offset(baseX + localX, baseY + localY));
      }
      
      if (token.isOnMain) {
          int absPos = engine.toAbsoluteMainIndex(token);
          List<Offset> path = BoardLayout.getLegacyPath(); 
          if (absPos < path.length) {
              Offset norm = path[absPos];
              // Convert norm (0..1) to pixel, based on 15 cells grid size
              // cw = (width-2pad)/15. So width-2pad = cw*15.
              double boardW = cw * 15;
              double boardH = ch * 15;
              return applyPadding(Offset(norm.dx * boardW, norm.dy * boardH));
          }
      }
      
       if (token.isInHomeStretch) {
           int stepsIn = token.position - 51; 
           if (stepsIn > 5) stepsIn = 6; 
           int x=0, y=0;
           switch(token.color) {
               case LudoColor.red: x = stepsIn; y = 7; if (stepsIn == 6) { x=6; y=7;} break;
               case LudoColor.green: x = 7; y = stepsIn; break;
               case LudoColor.yellow: x = 14 - stepsIn; y = 7; break;
               case LudoColor.blue: x = 7; y = 14 - stepsIn; break;
           }
           return applyPadding(Offset((x + 0.5) * cw, (y + 0.5) * ch));
       }
       
       if (token.isFinished) return applyPadding(Offset(cw * 7.5, ch * 7.5));
       return null;
  }
}

class LudoBoardPainter extends CustomPainter {
  final List<LudoPlayer> players;
  final LudoRpgEngine engine;
  final LudoColor activeColor;
  final ui.Image? boardImage;
  final String? selectedTokenId;

  LudoBoardPainter({
    required this.players, 
    required this.engine, 
    required this.activeColor,
    this.boardImage,
    this.selectedTokenId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (boardImage != null) {
         paintImage(
            canvas: canvas,
            rect: Rect.fromLTWH(0, 0, size.width, size.height),
            image: boardImage!,
            fit: BoxFit.fill
         );
    } else {
        final Paint bgPaint = Paint()..color = const Color(0xFF101015);
        canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height), bgPaint);
    }

    double padding = size.width * kBoardPaddingFactor;
    double playableW = size.width - 2*padding;
    double cellW = playableW / 15;
    double cellH = playableW / 15;

    canvas.save();
    canvas.translate(padding, padding); 

    if (kShowDebugGrid) {
        _drawDebugGrid(canvas, cellW, cellH);
    }

    // _drawStars(canvas, cellW, cellH); // Removed as requested
    _drawTokensSmart(canvas, cellW, cellH);

    canvas.restore();
  }

  void _drawDebugGrid(Canvas canvas, double cw, double ch) {
      final Paint p = Paint()
         ..color = Colors.greenAccent
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1;
      
      for(int i=0; i<=15; i++) {
          canvas.drawLine(Offset(i*cw, 0), Offset(i*cw, ch*15), p);
          canvas.drawLine(Offset(0, i*ch), Offset(cw*15, i*ch), p);
      }
      
      final Paint baseP = Paint()..color = Colors.red.withOpacity(0.3)..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0,0,6*cw,6*ch), baseP); 
      canvas.drawRect(Rect.fromLTWH(9*cw,0,6*cw,6*ch), baseP);
      canvas.drawRect(Rect.fromLTWH(0,9*cw,6*cw,6*ch), baseP); 
      canvas.drawRect(Rect.fromLTWH(9*cw,9*cw,6*cw,6*ch), baseP); 
  }

  void _drawTokensSmart(Canvas canvas, double cw, double ch) {
      final Map<String, List<LudoToken>> stackGroups = {};

      for (var player in players) {
          for (var token in player.tokens) {
              if (token.isDead) continue;
              if (token.isInBase) {
                  _drawToken(canvas, token, cw, ch, Offset.zero);
              } else {
                  String key = "";
                  if (token.isFinished) {
                      key = "GOAL";
                  } else if (token.isInHomeStretch) {
                      key = "HS_${token.color.name}_${token.position}";
                  } else {
                      int abs = engine.toAbsoluteMainIndex(token);
                      key = "M_$abs";
                  }
                  stackGroups.putIfAbsent(key, () => []).add(token);
              }
          }
      }

      stackGroups.forEach((key, tokens) {
          if (tokens.isEmpty) return;

          tokens.sort((a, b) {
             if (a.color == activeColor) return 1;
             if (b.color == activeColor) return -1;
             return 0; 
          });

          int count = tokens.length;
          Offset? center = _getTokenCoordinates(tokens[0], cw, ch); 
          if (center == null) return; 

          if (count == 1) {
              _drawToken(canvas, tokens[0], cw, ch, Offset.zero);
          } else {
              double radius = cw * 0.18; 
              for (int i = 0; i < count; i++) {
                  double angle = (2 * pi * i) / count - (pi / 2); 
                  if (count == 4) angle += (pi/4); 
                  
                  double ox = cos(angle) * radius;
                  double oy = sin(angle) * radius;
                  _drawToken(canvas, tokens[i], cw, ch, Offset(ox, oy)); 
              }
          }
      });
  }

  void _drawToken(Canvas canvas, LudoToken token, double cellW, double cellH, Offset offset) {
     if (token.isDead) return;
     Offset? pos = _getTokenCoordinates(token, cellW, cellH);
     if (pos != null) {
        final center = pos + offset;
        final paint = Paint()..style = PaintingStyle.fill;
        
        // Selection Ring
        if (selectedTokenId == token.id) {
            canvas.drawCircle(center, cellW * 0.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
            canvas.drawCircle(center, cellW * 0.5, Paint()..color = Colors.yellowAccent.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }

        paint.color = Colors.black38;
        canvas.drawCircle(center + const Offset(1,1), cellW * 0.35, paint);
        
        paint.color = Colors.black;
        canvas.drawCircle(center, cellW * 0.35, paint);
        
        paint.color = _getColor(token.color);
        canvas.drawCircle(center, cellW * 0.3, paint);

        paint.color = Colors.white;
        canvas.drawCircle(center, cellW * 0.1, paint);
     }
  }

  Offset? _getTokenCoordinates(LudoToken token, double cw, double ch) {
      if (token.isInBase) {
          // ... Base logic ...
          int index = int.tryParse(token.id.split('_').last) ?? 0;
          double baseX = 0, baseY = 0;
          switch(token.color) {
              case LudoColor.red: baseX=0; baseY=0; break;
              case LudoColor.green: baseX=cw*9; baseY=0; break;
              case LudoColor.yellow: baseX=cw*9; baseY=ch*9; break;
              case LudoColor.blue: baseX=0; baseY=ch*9; break;
          }
          double w = cw * 6;
          if (index == 0) return Offset(baseX + w*(2.5/6.0), baseY + w*(2.5/6.0));
          if (index == 1) return Offset(baseX + w*(3.5/6.0), baseY + w*(2.5/6.0));
          if (index == 2) return Offset(baseX + w*(2.5/6.0), baseY + w*(3.5/6.0));
          return Offset(baseX + w*(3.5/6.0), baseY + w*(3.5/6.0));
      }
      
      if (token.isOnMain) {
          int absPos = engine.toAbsoluteMainIndex(token);
          List<Offset> path = BoardLayout.getLegacyPath();
          if (absPos >= path.length) return null;
          Offset norm = path[absPos];
          double boardW = cw * 15;
          double boardH = ch * 15;
          return Offset(norm.dx * boardW, norm.dy * boardH);
      }
      
       if (token.isInHomeStretch) {
           int stepsIn = token.position - 51; 
           if (stepsIn > 5) stepsIn = 6; 
           int x=0, y=0;
           switch(token.color) {
               case LudoColor.red: x = stepsIn; y = 7; if (stepsIn == 6) { x=6; y=7;} break;
               case LudoColor.green: x = 7; y = stepsIn; break;
               case LudoColor.yellow: x = 14 - stepsIn; y = 7; break;
               case LudoColor.blue: x = 7; y = 14 - stepsIn; break;
           }
           return Offset((x + 0.5) * cw, (y + 0.5) * ch);
       }
       
       if (token.isFinished) return Offset(cw * 7.5, ch * 7.5);
       return null;
  }
  
  Color _getColor(LudoColor c) {
      switch(c) {
          case LudoColor.red: return Colors.red;
          case LudoColor.green: return Colors.green;
          case LudoColor.yellow: return Colors.amber; 
          case LudoColor.blue: return Colors.blue;
      }
  }

  void _drawStars(Canvas canvas, double cw, double ch) {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      final icon = Icons.star;
      final safeIndices = [0, 13, 26, 39];
      final path = BoardLayout.getLegacyPath();
      final pStars = Paint()..color = Colors.white.withOpacity(0.3);
      
      for (int idx in safeIndices) {
          if (idx < path.length) {
              Offset norm = path[idx];
              double cx = norm.dx * cw * 15;
              double cy = norm.dy * ch * 15;

              textPainter.text = TextSpan(
                  text: String.fromCharCode(icon.codePoint),
                  style: TextStyle(
                      fontSize: cw * 0.8, 
                      fontFamily: icon.fontFamily, 
                      package: icon.fontPackage,
                      color: Colors.white24 
                  )
              );
              textPainter.layout();
              textPainter.paint(canvas, Offset(cx - textPainter.width/2, cy - textPainter.height/2));
          }
      }
  }
  
  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) {
      return oldDelegate.selectedTokenId != selectedTokenId ||
             oldDelegate.activeColor != activeColor ||
             oldDelegate.boardImage != boardImage;
  } 
}
