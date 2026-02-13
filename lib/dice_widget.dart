import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

class DiceWidget extends StatelessWidget {
  final int value;
  final VoidCallback? onTap;
  final bool isEnabled;
  final double size;
  final bool isSelected;
  final Color? color;
  final bool isDoubled;
  final bool showD12;

  const DiceWidget({
    super.key,
    required this.value,
    this.onTap,
    this.isEnabled = true,
    this.color,
    this.size = 60.0,
    this.isSelected = false,
    this.isDoubled = false,
    this.showD12 = false,
    this.bonus = 0,
  });

  final int bonus;

  @override
  Widget build(BuildContext context) {
    // If value > 6 or D12 mode, we show Number instead of Pips
    // Debug
    // print("DiceWidget build: val=$value eff=$value doubled=$isDoubled showD12=$showD12");
    final bool showNumber = value > 6 || showD12;
    
    // Core Dice Visual
    Widget diceBody = AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        transform: isSelected ? Matrix4.identity().scaled(1.1) : Matrix4.identity(),
        decoration: BoxDecoration(
          // No box decoration for D12 (custom paint handles shape)
          // But we need shadow locally if standard
          borderRadius: showD12 ? null : BorderRadius.circular(12),
          boxShadow: (isSelected && !showD12) 
              ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.8), blurRadius: 12, spreadRadius: 2)] 
              : ((isEnabled && !showD12)
                  ? [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(2, 4))]
                  : []),
        ),
        child: CustomPaint(
          painter: _DicePainter(value, color ?? Colors.white, showNumber, showD12, isSelected),
          child: showNumber 
             ? Center(
                  child: Text(
                    "$value",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.45,
                      fontFamily: "Helvetica Neue",
                      color: ((color ?? Colors.white).computeLuminance() > 0.5)
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
               )
             : null,
        ),
      );

    // Add Stack for Badge if doubled
    if (isDoubled) {
        diceBody = Stack(
            clipBehavior: Clip.none,
            children: [
                diceBody,
                Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
                      ),
                      child: const Text(
                        "2×",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.black),
                      ),
                    ),
                ),
            ],
        );
    }

    // Add Stack for Bonus
    if (bonus > 0) {
         diceBody = Stack(
            clipBehavior: Clip.none,
            children: [
                diceBody,
                Positioned(
                    bottom: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green, // Different color for bonus
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
                      ),
                      child: Text(
                        "+$bonus",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                      ),
                    ),
                ),
            ],
        );
    }

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: diceBody,
    );
  }
}

class _DicePainter extends CustomPainter {
  final int value;
  final Color baseColor;
  final bool showNumber;
  final bool showD12;
  final bool isSelected;

  _DicePainter(this.value, this.baseColor, this.showNumber, this.showD12, this.isSelected);

  @override
  void paint(Canvas canvas, Size size) {
    if (showD12) {
        _paintD12(canvas, size);
    } else {
        _paintD6(canvas, size);
    }
  }
  
  void _paintD12(Canvas canvas, Size size) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2;
      
      final Paint paint = Paint()
        ..style = PaintingStyle.fill;
        
      if (baseColor.value == Colors.grey.value) {
          paint.color = Colors.grey.shade400; // Flat grey for used
      } else {
          // 3D Gradient for active D12
           paint.shader = RadialGradient(
              colors: [
                 baseColor,
                 _darken(baseColor, 0.3),
              ],
              center: Alignment.topLeft,
              radius: 1.2,
           ).createShader(Rect.fromCircle(center: center, radius: radius));
      }
      
      // Draw Hexagon for D12 silhouette
      final Path path = Path();
      for (int i = 0; i < 6; i++) {
          final double angle = (i * 60) * (pi / 180);
          final double x = center.dx + radius * cos(angle);
          final double y = center.dy + radius * sin(angle);
          if (i == 0) path.moveTo(x, y);
          else path.lineTo(x, y);
      }
      path.close();

      // Selection Glow (Draw FIRST or LAST? If Outer, doesn't matter much, but let's draw first to be behind?)
      // Actually Outer draws outside.
      if (isSelected) {
          canvas.drawPath(path, Paint()
              ..color = Colors.amber.shade400
              ..style = PaintingStyle.stroke // Stroke for outline glow? Or fill with mask?
              ..strokeWidth = 4
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          );
      }
      
      // Shadow
      canvas.drawPath(
          path.shift(const Offset(2, 4)), 
          Paint()..color = Colors.black45..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      );
      
      // BODY
      canvas.drawPath(path, paint);
      
      // Outline - Make it distinct to prevent "transparency" look
      final Paint outlinePaint = Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, outlinePaint);
      
      // Inner lines to suggest deca/dodeca
      final Paint linePaint = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
        
      // Simple inner pentagon? Or Y shape?
      // Y shape + inverted Y
      canvas.drawPath(path, linePaint); // Outline
      
      // Inner structure (simplified)
      // Connect center to vertices 0, 2, 4
      /*
      for (int i = 0; i < 6; i+=2) {
          final double angle = (i * 60) * (pi / 180);
          canvas.drawLine(center, Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)), linePaint);
      }
      */
  }

  void _paintD6(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(12));

    // 1. 3D Body Gradient
    // Use a simpler, flatter look for disabled/used dice (grey)
    final bool isGrey = baseColor.value == Colors.grey.value; // Heuristic
    
    final Paint bodyPaint = Paint();
    if (isGrey) {
        bodyPaint.color = Colors.grey.shade400; // Flat grey
    } else {
        bodyPaint.shader = RadialGradient(
          colors: [
             baseColor,
             _darken(baseColor, 0.3),
          ],
          center: Alignment.topLeft,
          radius: 1.2,
        ).createShader(rect);
    }

    canvas.drawRRect(rrect, bodyPaint);

    // 2. Border/Edge highlight
    canvas.drawRRect(
        rrect, 
        Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1
    );

    // 3. Pips (Dots)
    if (!showNumber) {
        final double pipRadius = size.width * 0.09;
        final Paint pipPaint = Paint()
            ..color = (baseColor.computeLuminance() > 0.5) ? Colors.black87 : Colors.white
            ..style = PaintingStyle.fill;
    
        void drawPip(double nx, double ny) {
           canvas.drawCircle(Offset(size.width * nx, size.height * ny), pipRadius, pipPaint);
        }
        
        // Logic for 1-6
        if (value % 2 != 0) {
           drawPip(0.5, 0.5); // Center
        }
        
        if (value > 1) {
           drawPip(0.2, 0.2); // TL
           drawPip(0.8, 0.8); // BR
        }
        
        if (value > 3) {
           drawPip(0.8, 0.2); // TR
           drawPip(0.2, 0.8); // BL
        }
        
        if (value == 6) {
           drawPip(0.2, 0.5); // Left-Mid
           drawPip(0.8, 0.5); // Right-Mid
        }
    }
  }
  
  Color _darken(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
      return darkened.toColor();
  }

  @override
  bool shouldRepaint(covariant _DicePainter oldDelegate) {
     return oldDelegate.value != value || 
            oldDelegate.baseColor != baseColor ||
            oldDelegate.showNumber != showNumber ||
            oldDelegate.showD12 != showD12 ||
            oldDelegate.isSelected != isSelected;
  }
}
