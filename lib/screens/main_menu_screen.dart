import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  final VoidCallback? onPlayLocal;
  final VoidCallback? onCreateOnlineRoom;
  final VoidCallback? onJoinOnlineRoom;

  const MainMenuScreen({
    super.key,
    this.onPlayLocal,
    this.onCreateOnlineRoom,
    this.onJoinOnlineRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Cosmic Background
          const Positioned.fill(child: _CosmicBackground()),

          // 2. Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Image.asset(
                      'assets/ludo-cards-identity.png',
                      height: 120, // Adjust as needed based on asset
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // GLASS PANEL
                    _GlassPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MainMenuButton(
                            label: "PLAY LOCAL",
                            icon: Icons.group,
                            gradientColors: const [Color(0xFF3BB6FF), Color(0xFF2A5BFF)],
                            onPressed: onPlayLocal,
                          ),
                          const SizedBox(height: 20),
                          _MainMenuButton(
                            label: "CREATE ONLINE ROOM",
                            icon: Icons.wifi,
                            gradientColors: const [Color(0xFFC83CFF), Color(0xFF6A2DFF)],
                            onPressed: onCreateOnlineRoom,
                          ),
                          const SizedBox(height: 20),
                          _MainMenuButton(
                            label: "JOIN ONLINE ROOM",
                            icon: Icons.login,
                            gradientColors: const [Color(0xFFFFD24A), Color(0xFFFF9E2C)],
                            onPressed: onJoinOnlineRoom,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACKGROUND WIDGETS
// ---------------------------------------------------------------------------

class _CosmicBackground extends StatelessWidget {
  const _CosmicBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Gradient (Indigo -> darker violet)
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2), // slightly up
              radius: 1.5,
              colors: [
                Color(0xFF1A1A3D), // lighter center (indigo-ish)
                Color(0xFF0B1020), // dark corners
              ],
            ),
          ),
        ),

        // Noise Overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _NoisePainter(),
          ),
        ),

        // Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.4),
              ],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  final math.Random _random = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    // Very lightweight noise
    // Draw tiny rects or points randomly
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03) // Subtle
      ..style = PaintingStyle.fill;
      
    // Draw 3000 random specs
    for (int i = 0; i < 3000; i++) {
        final x = _random.nextDouble() * size.width;
        final y = _random.nextDouble() * size.height;
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// GLASS PANEL
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    // Width constraint relative to screen
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = math.min(520.0, 0.82 * screenWidth);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: panelWidth,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10), // Translucent fill
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GLOWING GRADIENT BUTTON
// ---------------------------------------------------------------------------

class _MainMenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onPressed;

  const _MainMenuButton({
    required this.label,
    required this.icon,
    required this.gradientColors,
    this.onPressed,
  });

  @override
  State<_MainMenuButton> createState() => _MainMenuButtonState();
}

class _MainMenuButtonState extends State<_MainMenuButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  
  bool _isPressed = false; // logic present for tracking state if needed later

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(_scaleCtrl);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleCtrl.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleCtrl.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
     setState(() => _isPressed = false);
    _scaleCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          );
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              // Glow shadow
              BoxShadow(
                color: widget.gradientColors.last.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
               // Top highlight
               Positioned(
                 top: 0,
                 left: 0,
                 right: 0,
                 height: 20,
                 child: Container(
                   decoration: BoxDecoration(
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                     gradient: LinearGradient(
                       begin: Alignment.topCenter,
                       end: Alignment.bottomCenter,
                       colors: [
                         Colors.white.withOpacity(0.2),
                         Colors.transparent,
                       ],
                     ),
                   ),
                 ),
               ),
               
               // Content
               Center(
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(widget.icon, color: Colors.white, size: 24),
                     const SizedBox(width: 12),
                     Text(
                       widget.label,
                       style: const TextStyle(
                         color: Colors.white, // In case, ensure explicit white
                         fontFamily: 'Roboto', // Fallback
                         fontSize: 16,
                         fontWeight: FontWeight.w600, // Semi-bold
                         letterSpacing: 1.2,
                       ),
                     )
                   ],
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}

