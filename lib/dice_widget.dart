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

  const DiceWidget({
    super.key,
    required this.value,
    this.onTap,
    this.isEnabled = true,
    this.color,
    this.size = 60.0,
    this.isSelected = false,
    this.isDoubled = false,
  });

  @override
  Widget build(BuildContext context) {
    // If value > 6, we show Number instead of Pips
    final bool showNumber = value > 6;
    
    // Core Dice Visual
    Widget diceBody = AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        transform: isSelected ? Matrix4.identity().scaled(1.1) : Matrix4.identity(),
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          borderRadius: BorderRadius.circular(12), // Match painter radius roughly
          boxShadow: isSelected 
              ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.8), blurRadius: 12, spreadRadius: 2)] 
              : (isEnabled 
                  ? [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(2, 4))]
                  : []),
        ),
        child: CustomPaint(
          painter: _DicePainter(value, color ?? Colors.white, showNumber),
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

  _DicePainter(this.value, this.baseColor, this.showNumber);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(12));

    // 1. 3D Body Gradient
    // Radial gradient offset to top-left to look like light source
    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
           baseColor,
           _darken(baseColor, 0.3),
        ],
        center: Alignment.topLeft,
        radius: 1.2,
      ).createShader(rect);

    canvas.drawRRect(rrect, bodyPaint);

    // 2. Border/Edge highlight
    canvas.drawRRect(
        rrect, 
        Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1
    );

    // 3. Pips (Dots) - ONLY if <= 6 (showNumber is false)
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
           drawPip(0.5, 0.5); // Center (1, 3, 5)
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
     return oldValue != value || oldColor != baseColor;
  }
  
  int get oldValue => (this as dynamic).value; // Should ideally cast properly but standard pattern ok
  Color get oldColor => (this as dynamic).baseColor;
}
