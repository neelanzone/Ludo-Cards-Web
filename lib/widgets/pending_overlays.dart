import 'package:flutter/material.dart';
import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/models/ludo_game_state.dart';
import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/data/card_library.dart';

class PendingOverlay extends StatelessWidget {
  final LudoRpgGameState gs;
  final Function(Map<String, dynamic>) onResolve;
  
  const PendingOverlay({super.key, required this.gs, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    if (gs.pending == null) return const SizedBox.shrink();

    final type = gs.pending!.type;
    final data = gs.pending!.data;

    // Determine if we should dim the background (block interaction)
    bool dimBackground = true;
    if (type == PendingType.pickDieToDouble || 
        type == PendingType.pickDieToReroll ||
        type == PendingType.pickToken1 ||
        type == PendingType.pickToken2 || 
        type == PendingType.pickAttackTarget || 
        type == PendingType.selectAttackTarget) {
        dimBackground = false;
    }

    return Stack(
      children: [
        // Dim Background
        if (dimBackground)
            Container(color: Colors.black54),

        // Content
        _buildContent(context, type, data),
      ],
    );
  }

  Widget _buildContent(BuildContext context, PendingType type, Map<String, dynamic> data) {
    switch (type) {
      case PendingType.pickDieToDouble:
      case PendingType.pickDieToReroll:
        return const Positioned(
            top: 100,
            left: 0, 
            right: 0,
            child: Center(
              child: Material(
                  color: Colors.transparent,
                  child: Text("Tap a Die to Select", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))
              )
            )
        );
      
      case PendingType.selectAttackTarget:
      case PendingType.pickAttackTarget: // Alias
         return const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                  color: Colors.transparent,
                  child: Text("Select Enemy Target", style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))
              )
            )
         );
         
      case PendingType.pickAttackDirection:
          // Legacy: Laser now auto-detects direction. This case should never fire.
          return const SizedBox.shrink();
         
      case PendingType.selectResurrectTarget:
          return SafeArea(child: Center(
            child: _ResurrectPicker(
              tokens: gs.currentPlayer.tokens.where((t) => t.isDead).toList(),
              onResolve: (id) => onResolve({"tokenId": id}),
            )
          ));

      case PendingType.pickToken1:
      case PendingType.pickToken2:
        String msg = type == PendingType.pickToken2 ? "Select Two Tokens" : "Select a Token";
        // Contextual messages
        if (gs.pending?.sourceCardId.startsWith("Attack") == true) msg = "Select Weapon Source";
        if (gs.pending?.sourceCardId.startsWith("Defence") == true) msg = "Select Token to Protect";
        
        return Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                  color: Colors.transparent,
                  child: Text(
                       msg,
                       style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])
                  )
              )
            )
        );
        
      case PendingType.confirmRerollChoiceSingle:
        return SafeArea(child: Center(
          child: _RerollConfirmDialog(
            oldVal: data["old"], 
            newVal: data["new"],
            dieIndex: data["dieIndex"],
            onResolve: onResolve
          )
        ));
        
      case PendingType.confirmRerollChoiceBoth:
        return SafeArea(child: Center(
          child: _RerollConfirmBothDialog(
            data: data,
            onResolve: onResolve
          )
        ));

      case PendingType.pickPlayer:
        return SafeArea(child: Center(
          child: _PlayerPicker(
            currentPlayer: gs.currentPlayer.color,
            onResolve: onResolve
          )
        ));

      case PendingType.pickCardFromOpponentHand:
        return SafeArea(child: Center(
          child: _HandPicker(
            title: "Pick a Card to Steal",
            cardIds: gs.hands[LudoColor.values.firstWhere((c) => c.toString().split('.').last == data["targetColor"])]!,
            onResolve: (cardId) => onResolve({"cardId": cardId}),
          )
        ));
        
      case PendingType.pickCardFromYourHand:
        return SafeArea(child: Center(
          child: _HandPicker(
            title: "Pick a Card to Give",
            cardIds: gs.hands[gs.currentPlayer.color]!,
            onResolve: (cardId) => onResolve({"cardId": cardId}),
          )
        ));

      case PendingType.robinPickCard:
         return SafeArea(child: Center(
           child: _HandPicker(
            title: "Distribute: Pick Cards",
            cardIds: List<String>.from(data["pool"]),
            onResolve: (result) => onResolve({"cardIds": result}), // Pass list or single
            allowMulti: true,
           )
         ));
         
      case PendingType.robinPickRecipient:
         return SafeArea(child: Center(
           child: _PlayerPicker(
             currentPlayer: gs.currentPlayer.color,
             excludeColors: [
                 gs.currentPlayer.color,
                 LudoColor.values.firstWhere((c) => c.toString().split('.').last == data["victim"])
             ],
             title: "Pick Recipient",
             onResolve: (colorMap) => onResolve({"recipientColor": colorMap["targetColor"]}),
           )
         ));

      case PendingType.dumpsterBrowsePick:
         final snapshot = List<String>.from(data["snapshot"]);
         return SafeArea(child: Center(
           child: _DumpsterBrowser(
             cardIds: snapshot,
             onResolve: onResolve
           )
         ));

      default:
        return SafeArea(child: Center(child: Text("Unknown Pending Type: $type", style: const TextStyle(color: Colors.red))));
    }
  }
}

// --- Sub Widgets ---

class _RerollConfirmDialog extends StatelessWidget {
  final int oldVal;
  final int newVal;
  final int dieIndex;
  final Function(Map<String, dynamic>) onResolve;

  const _RerollConfirmDialog({required this.oldVal, required this.newVal, required this.dieIndex, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Reroll Die ${dieIndex == 0 ? 'A' : 'B'}"),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
           _DiePreview(oldVal, "Old"),
           const Icon(Icons.arrow_forward),
           _DiePreview(newVal, "New"),
        ],
      ),
      actions: [
        TextButton(onPressed: () => onResolve({"keep": "old"}), child: const Text("Keep Old")),
        ElevatedButton(onPressed: () => onResolve({"keep": "new"}), child: const Text("Keep New")),
      ],
    );
  }
}

class _RerollConfirmBothDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onResolve;

  const _RerollConfirmBothDialog({required this.data, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reroll Both Dice"),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Old Roll:"),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_DiePreview(data["oldA"], ""), const SizedBox(width: 8), _DiePreview(data["oldB"], "")]),
            const Divider(),
            const Text("New Roll:"),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_DiePreview(data["newA"], ""), const SizedBox(width: 8), _DiePreview(data["newB"], "")]),
          ]
      ),
      actions: [
        TextButton(onPressed: () => onResolve({"keep": "old"}), child: const Text("Keep Old")),
        ElevatedButton(onPressed: () => onResolve({"keep": "new"}), child: const Text("Keep New")),
      ],
    );
  }
}

class _DiePreview extends StatelessWidget {
  final int val;
  final String label;
  const _DiePreview(this.val, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(label), Container(width: 40, height: 40, color: Colors.black12, child: Center(child: Text("$val", style: const TextStyle(fontWeight: FontWeight.bold))))]);
  }
}

class _PlayerPicker extends StatelessWidget {
  final LudoColor currentPlayer;
  final List<LudoColor> excludeColors;
  final String title;
  final Function(Map<String, dynamic>) onResolve;

  const _PlayerPicker({
      required this.currentPlayer, 
      this.excludeColors = const [],
      this.title = "Pick a Player",
      required this.onResolve
  });

  @override
  Widget build(BuildContext context) {
    // 4 corners or just a row?
    // User requested "coloured circles with the caption 'Pick a Player to steal from'"
    // two click confirm.
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
           color: const Color(0xFF1E2630), // Dark dialog bg
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: Colors.white24),
           boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)]
        ),
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
               Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               const SizedBox(height: 32),
               Wrap(
                   spacing: 20,
                   runSpacing: 20,
                   alignment: WrapAlignment.center,
                   children: LudoColor.values.where((c) => c != currentPlayer && !excludeColors.contains(c)).map((c) {
                       return _PlayerCircle(color: c, onResolve: onResolve);
                   }).toList(),
               )
           ],
        ),
      ),
    );
  }
}

class _PlayerCircle extends StatefulWidget {
    final LudoColor color;
    final Function(Map<String, dynamic>) onResolve;
    const _PlayerCircle({required this.color, required this.onResolve});
    @override
    State<_PlayerCircle> createState() => _PlayerCircleState();
}

class _PlayerCircleState extends State<_PlayerCircle> {
    bool selected = false;
    
    Color get _uiColor {
        switch (widget.color) {
            case LudoColor.red: return Colors.red;
            case LudoColor.green: return Colors.green;
            case LudoColor.yellow: return Colors.amber;
            case LudoColor.blue: return Colors.blue;
        }
    }

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: () {
                if (selected) {
                    // Confirm
                    widget.onResolve({"targetColor": widget.color.toString().split('.').last.toLowerCase()});
                } else {
                    setState(() => selected = true);
                }
            },
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 90 : 80,
                height: selected ? 90 : 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _uiColor,
                    border: selected ? Border.all(color: Colors.white, width: 4) : null,
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)]
                ),
                child: Center(
                    child: selected ? const Icon(Icons.check, color: Colors.white, size: 40) : null
                ),
            ),
        );
    }
}

class _HandPicker extends StatefulWidget {
  final String title;
  final List<String> cardIds;
  final Function(dynamic) onResolve; // Returns String or List<String>
  final bool allowMulti;

  const _HandPicker({required this.title, required this.cardIds, required this.onResolve, this.allowMulti = false});

  @override
  State<_HandPicker> createState() => _HandPickerState();
}

class _HandPickerState extends State<_HandPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
      return Container(
          width: 300,
          height: 450,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
              children: [
                  Padding(padding: const EdgeInsets.all(16), child: 
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            if (widget.allowMulti)
                                ElevatedButton(
                                    onPressed: _selected.isNotEmpty ? () {
                                        widget.onResolve(_selected.toList());
                                    } : null,
                                    child: const Text("Distribute")
                                )
                        ]
                    )
                  ),
                  Expanded(
                      child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
                          itemCount: widget.cardIds.length,
                          itemBuilder: (ctx, i) {
                               final id = widget.cardIds[i];
                               final templateId = id.contains('_') ? id.split('_')[0] : id;
                               final isSelected = _selected.contains(id);
                               
                               return GestureDetector(
                                   onTap: () {
                                       if (widget.allowMulti) {
                                           setState(() {
                                               if (isSelected) _selected.remove(id);
                                               else _selected.add(id);
                                           });
                                       } else {
                                           widget.onResolve(id);
                                       }
                                   },
                                   child: Stack(
                                       children: [
                                           Image.asset("assets/cards/$templateId.png", fit: BoxFit.fill,
                                             errorBuilder: (ctx, err, stack) => Container(color: Colors.grey, child: const Icon(Icons.error)),
                                           ),
                                           if (widget.allowMulti && isSelected)
                                               Container(
                                                   color: Colors.black45,
                                                   child: const Center(child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 40))
                                               )
                                       ]
                                   ), 
                               );
                           }
                       )
                  ),
              ],
          )
      );
  }
}

class _DumpsterBrowser extends StatefulWidget {
  final List<String> cardIds;
  final Function(Map<String, dynamic>) onResolve;
  const _DumpsterBrowser({required this.cardIds, required this.onResolve});
  
  @override
  State<_DumpsterBrowser> createState() => _DumpsterBrowserState();
}

class _DumpsterBrowserState extends State<_DumpsterBrowser> {
  int timeLeft = 15;
  
  @override
  void initState() {
      super.initState();
      _tick();
  }
  
  void _tick() {
      Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          if (timeLeft > 0) {
              setState(() => timeLeft--);
              _tick();
          } else {
              widget.onResolve({"timeout": true});
          }
      });
  }

  @override
  Widget build(BuildContext context) {
      return Container(
          width: 320,
          height: 500,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
              children: [
                  Padding(padding: const EdgeInsets.all(16), child: 
                     Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                         const Text("Dumpster Dive", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                         Text("$timeLeft s", style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
                     ])
                  ),
                  Expanded(
                      child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
                          itemCount: widget.cardIds.length,
                          itemBuilder: (ctx, i) {
                              final id = widget.cardIds[i];
                              final templateId = id.split('_')[0];
                              return GestureDetector(
                                  onTap: () => widget.onResolve({"cardId": id, "timeout": false}),
                                  child: Image.asset("assets/cards/$templateId.png", fit: BoxFit.fill), 
                              );
                          }
                      )
                  ),
              ],
          )
      );
  }
}

class _ResurrectPicker extends StatelessWidget {
  final List<LudoToken> tokens;
  final Function(String) onResolve;
  
  const _ResurrectPicker({required this.tokens, required this.onResolve});

  @override
  Widget build(BuildContext context) {
      return Center(
          child: Material(
              color: Colors.transparent,
              child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          const Text("Select Token to Resurrect", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          if (tokens.isEmpty)
                              const Text("No dead tokens.", style: TextStyle(color: Colors.white70)),
                          
                          ...tokens.map((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[800],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  onPressed: () => onResolve(t.id),
                                  child: Text("Token ${t.id.split('_').last}", style: const TextStyle(fontSize: 18)),
                              ),
                          )).toList()
                      ],
                  ),
              ),
          ),
      );
  }
}
