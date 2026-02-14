import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/models/ludo_game_state.dart';

class MultiplayerService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  User? _user;
  String? _roomId;
  String? _localPlayerId; // The UID of this client
  LudoColor? _localColor;
  
  // Game State Stream
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _playersSubscription;
  StreamSubscription<DocumentSnapshot>? _lobbyStateSubscription; // New lobby state listener
  
  LudoRpgGameState? _currentGameState;
  List<Map<String, dynamic>> _lobbyPlayers = [];
  String _roomStatus = 'lobby'; // lobby, playing, ended

  // New Lobby State Fields
  Map<LudoColor, String> _lockedColors = {};
  Map<String, LudoColor> _tentativeColors = {};
  Map<String, bool> _playerReady = {};
  
  User? get user => _user;
  String? get roomId => _roomId;
  String? get localPlayerId => _localPlayerId;
  LudoColor? get localColor => _localColor;
  LudoRpgGameState? get gameState => _currentGameState;
  List<Map<String, dynamic>> get lobbyPlayers => _lobbyPlayers;
  bool get isHost => _lobbyPlayers.isNotEmpty && _lobbyPlayers.first['uid'] == _localPlayerId;
  String get roomStatus => _roomStatus;
  
  Map<LudoColor, String> get lockedColors => _lockedColors;
  Map<String, LudoColor> get tentativeColors => _tentativeColors;
  Map<String, bool> get playerReady => _playerReady;
  
  // Computed helpers
  bool get iAmReady => _playerReady[_localPlayerId] ?? false;
  bool get allPlayersReady => _lobbyPlayers.isNotEmpty && _lobbyPlayers.every((p) => _playerReady[p['uid']] == true);
  
  String _lastSyncLog = "Waiting for sync...";
  String get lastSyncLog => _lastSyncLog;

  Future<void> signIn() async {
    if (_user == null) {
      final cred = await _auth.signInAnonymously();
      _user = cred.user;
      _localPlayerId = _user!.uid;
      notifyListeners();
    } else {
        _localPlayerId = _user!.uid;
    }
  }

  Future<String> createRoom() async {
    await signIn();
    
    // Generate a short ID (6 chars)
    final roomId = _uuid.v4().substring(0, 6).toUpperCase();
    
    // Create Room Doc
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'lobby',
      'hostUid': _localPlayerId,
      'createdAt': FieldValue.serverTimestamp(),
      'maxPlayers': 4,
      'turn': 0,
      'rev': 1,
      // 'takenColors': [], // Track taken colors - now handled by lobby/state
    });
    
    await joinRoom(roomId);
    return roomId;
  }

  Future<void> joinRoom(String roomId) async {
    await signIn();
    
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnap = await roomRef.get();
    
    if (!roomSnap.exists) throw Exception("Room does not exist");
    // TODO: cleanup checks (maxPlayers, status == lobby)
    
    // Create Player Doc
    // Default name
    final name = "Player ${_uuid.v4().substring(0, 4)}";
    
    await roomRef.collection('players').doc(_localPlayerId).set({
      'name': name,
      'uid': _localPlayerId,
      'color': null, // Not selected yet
      'isReady': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    _roomId = roomId;
    _listenToRoom();
    notifyListeners();
  }

  void _listenToRoom() {
    if (_roomId == null) return;
    
    final roomRef = _firestore.collection('rooms').doc(_roomId);
    
    // 1. Room Metadata Listener
    _roomSubscription = roomRef.snapshots().listen((snap) {
        print("📡 SNAPSHOT RECEIVED: exists=${snap.exists}");
        if (!snap.exists) {
            print("⚠️ Room doesn't exist!");
            _roomStatus = 'ended';
            notifyListeners();
            return;
        }
        final data = snap.data() as Map<String, dynamic>;
        _roomStatus = data['status'] ?? 'lobby';
        print("📡 Room status: $_roomStatus, hasGameState: ${data.containsKey('gameState')}");
        
        // Listen for Game State (if playing)
        if (_roomStatus == 'playing' && data.containsKey('gameState')) {
            // Decode GameState
            try {
                // If the game state is stored in the room doc
                final gsJson = data['gameState'];
                if (gsJson != null) {
                    final incoming = LudoRpgGameState.fromJson(gsJson);
                    // Optimistic Concurrency Check: Only apply if newer or same
                    // (Same is ok to ensure sync, but if we are ahead locally, we ignore old remote echo)
                    // If we just wrote version V, and echo comes back as V, it's fine.
                    // If we wrote V, and current local is V+1 (another action), and echo is V.
                    // V+1 > V, so we ignore echo.
                    // If remote wrote V+2, we accept.
                    
                    int currentVer = _currentGameState?.version ?? -1;
                    print("SYNC: Incoming v${incoming.version} (Idx:${incoming.currentPlayerIndex}) vs Local v$currentVer");
                    
                    if (incoming.version == currentVer) {
                         // Duplicate/Echo
                         _lastSyncLog = "Echo v${incoming.version} idx:${incoming.currentPlayerIndex}";
                         print("SYNC: Echo detected, notifying listeners anyway");
                    } else if (incoming.version > currentVer) {
                         _currentGameState = incoming;
                         _lastSyncLog = "Acc v${incoming.version} idx:${incoming.currentPlayerIndex}";
                         print("SYNC: Accepted newer version, updating state");
                         notifyListeners();
                    } else {
                        // incoming < current
                        _lastSyncLog = "Ign v${incoming.version} < Loc v$currentVer";
                        print("SYNC IGNORED: Local is ahead.");
                    }
                    print("SYNC: Calling notifyListeners (final)");
                    notifyListeners();
                } else {
                    print("⚠️ gameState is null!");
                }
            } catch (e) {
                print("Error parsing game state: $e");
                _lastSyncLog = "Err: $e";
                notifyListeners();
            }
        } else {
            print("📡 Not playing or no gameState");
            notifyListeners();
        }
    });

    // 2. Players List Listener
    _playersSubscription = roomRef.collection('players').orderBy('joinedAt').snapshots().listen((snap) {
        _lobbyPlayers = snap.docs.map((d) => d.data()).toList();
        notifyListeners();
    });
    
    // 3. Lobby State Listener (New)
    _lobbyStateSubscription = roomRef.collection('lobby').doc('state').snapshots().listen((snap) {
        if (snap.exists) {
            final data = snap.data()!;
            
            // Parse Locked
            _lockedColors.clear();
            final lockedMap = data['locked'] as Map<String, dynamic>? ?? {};
            lockedMap.forEach((k, v) {
                if (v != null) {
                    _lockedColors[LudoColorExt.fromString(k)] = v as String;
                }
            });

            // Parse Tentative
            _tentativeColors.clear();
            final tentativeMap = data['tentative'] as Map<String, dynamic>? ?? {};
            tentativeMap.forEach((k, v) {
                if (v != null) {
                    _tentativeColors[k] = LudoColorExt.fromString(v as String);
                }
            });

            // Parse Ready
            _playerReady.clear();
            final readyMap = data['ready'] as Map<String, dynamic>? ?? {};
            readyMap.forEach((k, v) {
                _playerReady[k] = v as bool;
            });
            
            // Update local color helper (priority: locked > tentative)
            if (_localPlayerId != null) {
                // If locked, usage is authoritative
                // If not locked, use tentative
                // We prefer locked
                
                // Find if I have a locked color
                LudoColor? myLocked;
                _lockedColors.forEach((c, uid) {
                    if (uid == _localPlayerId) myLocked = c;
                });
                
                if (myLocked != null) {
                    _localColor = myLocked;
                } else {
                    _localColor = _tentativeColors[_localPlayerId];
                }
            }
            
            notifyListeners();
        }
    });
  }
  
  Future<void> forceRefresh() async {
      _lastSyncLog = "Forcing Refresh...";
      notifyListeners();
      try {
          final doc = await _firestore.collection('rooms').doc(_roomId).get();
          if (doc.exists && doc.data()!.containsKey('gameState')) {
              final gsJson = doc.data()!['gameState'];
              final incoming = LudoRpgGameState.fromJson(gsJson);
              _currentGameState = incoming;
              _lastSyncLog = "Forced v${incoming.version} idx:${incoming.currentPlayerIndex}";
              print("FORCE REFRESH: Loaded v${incoming.version}");
              notifyListeners();
          } else {
              _lastSyncLog = "Force Failed: No Data";
              notifyListeners();
          }
      } catch(e) {
          _lastSyncLog = "Force Err: $e";
          notifyListeners();
      }
  }
  
  // Set Tentative (Fast Write)
  Future<void> setTentative(LudoColor color) async {
      if (_roomId == null || _localPlayerId == null) return;
      if (iAmReady) return; // Cannot change if ready
      
      // Check if locked by someone else
      if (_lockedColors.containsKey(color) && _lockedColors[color] != _localPlayerId) return;

      final lobbyRef = _firestore.collection('rooms').doc(_roomId).collection('lobby').doc('state');
      
      // Use set with merge to create if not exists
      await lobbyRef.set({
          'tentative': {
              _localPlayerId: color.toShortString()
          }
      }, SetOptions(merge: true));
  }

  // Confirm Selection / Toggle Ready
  Future<bool> confirmSelection() async {
      if (_roomId == null || _localPlayerId == null) return false;
      
      // If already ready, unready? (Optional - for now let's say Confirm locks it)
      // If we want to allow un-ready, we'd need a different flow. 
      // User request says "Confirm button -> locks and sets ready".
      
      LudoColor? myTentative = _tentativeColors[_localPlayerId];
      if (myTentative == null) return false; // Nothing to confirm
      
      final lobbyRef = _firestore.collection('rooms').doc(_roomId).collection('lobby').doc('state');
      final roomRef = _firestore.collection('rooms').doc(_roomId);

      try {
          await _firestore.runTransaction((transaction) async {
              final snap = await transaction.get(lobbyRef);
              
              Map<String, dynamic> lockedMap = {};
              if (snap.exists) {
                  lockedMap = Map<String, dynamic>.from(snap.data()?['locked'] ?? {});
              }
              
              final colorStr = myTentative!.toShortString();
              
              // Check if taken (race condition)
              if (lockedMap.containsKey(colorStr) && lockedMap[colorStr] != _localPlayerId) {
                  throw Exception("Color taken during confirm");
              }
              
              // Lock it
              // Remove my ID from any other locked color (just in case)
              lockedMap.removeWhere((k, v) => v == _localPlayerId);
              lockedMap[colorStr] = _localPlayerId;
              
              transaction.set(lobbyRef, {
                  'locked': lockedMap,
                  'ready': { _localPlayerId: true }
              }, SetOptions(merge: true));
              
              // Update player doc in root collection for legacy compatibility/display
              transaction.update(roomRef.collection('players').doc(_localPlayerId), {
                  'color': colorStr,
                  'isReady': true
              });
          });
          return true;
      } catch (e) {
          print("Confirm failed: $e");
          return false;
      }
  }

  Future<void> startGame(LudoRpgGameState initialState) async {
      if (_roomId == null) return;
      
      // Serialize
      final json = initialState.toJson();
      
      await _firestore.collection('rooms').doc(_roomId).update({
          'status': 'playing',
          'gameState': json,
      });
      _currentGameState = initialState; // Optimistic
  }
  
  Future<void> updateGameState(LudoRpgGameState newState) async {
      if (_roomId == null) {
          print("UPDATE FAILED: No room ID");
          _lastSyncLog = "Write Err: No Room";
          notifyListeners();
          return;
      }
      
      // DO NOT optimistically update - let Firestore snapshot handle it
      // This prevents version mismatch where local state gets ahead
      
      try {
          final json = newState.toJson();
          print("WRITE: Attempting v${newState.version} idx:${newState.currentPlayerIndex}");
          await _firestore.collection('rooms').doc(_roomId).update({
              'gameState': json,
          });
          print("WRITE SUCCESS: v${newState.version}");
          _lastSyncLog = "Wrote v${newState.version} idx:${newState.currentPlayerIndex}";
          // State will be updated via snapshot listener
      } catch (e) {
          print("WRITE FAILED: $e");
          _lastSyncLog = "Write Err: $e";
          notifyListeners();
      }
  }

  void leaveRoom() {
     _roomSubscription?.cancel();
     _playersSubscription?.cancel();
     _lobbyStateSubscription?.cancel(); // Cancel new subscription
     _roomId = null;
     _roomStatus = 'lobby';
     _lobbyPlayers = [];
     _currentGameState = null;
     _lockedColors = {}; // Clear new state
     _tentativeColors = {}; // Clear new state
     _playerReady = {}; // Clear new state
     notifyListeners();
  }
}
