import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Super Mario Strategy - Digimon Edition',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

// ==========================================
// GAME STATE & MODELS
// ==========================================
class Player {
  double x = 50;
  double y = 100;
  double w = 28;
  double h = 32;
  double dx = 0;
  double dy = 0;
  bool grounded = false;
  bool facingRight = true;
}

class Block {
  double x, y, w, h;
  Block(this.x, this.y, this.w, this.h);
}

class Enemy {
  double x, y, w, h, dx, minX, maxX;
  bool alive = true;
  Enemy(this.x, this.y, this.w, this.h, this.dx, this.minX, this.maxX);
}

class Fireball {
  double x, y, dx;
  Fireball(this.x, this.y, this.dx);
}

class Item {
  String type;
  double x, y;
  bool collected = false;
  Item(this.type, this.x, this.y);
}

// ==========================================
// MAIN GAME SCREEN (UI & ENGINE LOOP)
// ==========================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? gameLoopTimer;
  Player player = Player();

  int stage = 1;
  int lives = 3;
  int ammo = 30;
  double cameraX = 0;

  // Inventory
  int daging = 0;
  int ramuan = 0;
  int sisik = 0;
  int cakar = 0;
  bool kunci = false;

  bool isInvincible = false;
  bool isDoubleDamage = false;

  List<Block> platforms = [];
  List<Enemy> enemies = [];
  List<Fireball> fireballs = [];
  List<Item> items = [];
  Block? flagPole;

  bool keyLeft = false;
  bool keyRight = false;

  @override
  void initState() {
    super.initState();
    loadStage(1);
    startGameLoop();
  }

  @override
  void dispose() {
    gameLoopTimer?.cancel();
    super.dispose();
  }

  void loadStage(int stgNo) {
    stage = stgNo;
    player.x = 50;
    player.y = 100;
    player.dx = 0;
    player.dy = 0;
    fireballs.clear();

    if (stage == 1) {
      platforms = [
        Block(0, 220, 900, 50),
        Block(980, 140, 180, 20),
        Block(1240, 80, 200, 20),
        Block(1500, 220, 1000, 50),
      ];
      enemies = [
        Enemy(600, 194, 26, 26, 80, 500, 700),
        Enemy(750, 194, 26, 26, -70, 650, 850),
        Enemy(1600, 194, 26, 26, 90, 1500, 1750),
      ];
      items = [
        Item('daging', 350, 180),
        Item('ramuan', 700, 180),
        Item('sisik', 1300, 40),
        Item('kunci', 1900, 180),
      ];
      flagPole = Block(2300, 60, 10, 160);
    } else if (stage == 2) {
      platforms = [
        Block(0, 220, 700, 50),
        Block(780, 120, 200, 20),
        Block(1050, 220, 1200, 50),
      ];
      enemies = [
        Enemy(500, 194, 26, 26, 60, 400, 600),
        Enemy(900, 94, 26, 26, -70, 800, 950),
      ];
      items = [
        Item('ramuan', 200, 180),
        Item('cakar', 850, 80),
        Item('kunci', 1650, 180),
      ];
      flagPole = Block(2000, 60, 10, 160);
    }
  }

  void startGameLoop() {
    gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      updatePhysics(0.016);
    });
  }

  void updatePhysics(double dt) {
    setState(() {
      // Horizontal Input
      if (keyLeft) {
        player.dx = -160;
        player.facingRight = false;
      } else if (keyRight) {
        player.dx = 160;
        player.facingRight = true;
      } else {
        player.dx = 0;
      }

      player.x += player.dx * dt;

      // Gravity & Vertical Movement
      player.dy += 950 * dt;
      if (player.dy > 600) player.dy = 600;
      player.y += player.dy * dt;

      // Platform Collisions
      player.grounded = false;
      for (var p in platforms) {
        if (player.x < p.x + p.w &&
            player.x + player.w > p.x &&
            player.y < p.y + p.h &&
            player.y + player.h > p.y) {
          if (player.dy >= 0 && player.y + player.h - player.dy * dt <= p.y + 12) {
            player.y = p.y - player.h;
            player.dy = 0;
            player.grounded = true;
          }
        }
      }

      // Camera Follow
      cameraX = max(0, player.x - 120);

      // Enemy Logic
      for (var e in enemies) {
        if (!e.alive) continue;
        e.x += e.dx * dt;
        if (e.x < e.minX || e.x > e.maxX) e.dx *= -1;

        // Hit Player
        if (player.x < e.x + e.w &&
            player.x + player.w > e.x &&
            player.y < e.y + e.h &&
            player.y + player.h > e.y) {
          handleDeath();
        }
      }

      // Fireballs Movement & Hits
      for (int i = fireballs.length - 1; i >= 0; i--) {
        var fb = fireballs[i];
        fb.x += fb.dx * dt;

        for (var e in enemies) {
          if (e.alive &&
              fb.x < e.x + e.w &&
              fb.x + 10 > e.x &&
              fb.y < e.y + e.h &&
              fb.y + 10 > e.y) {
            e.alive = false;
            fireballs.removeAt(i);
            break;
          }
        }
      }

      // Item Collection
      for (var item in items) {
        if (!item.collected &&
            player.x < item.x + 20 &&
            player.x + player.w > item.x &&
            player.y < item.y + 20 &&
            player.y + player.h > item.y) {
          item.collected = true;
          if (item.type == 'daging') daging++;
          if (item.type == 'ramuan') ramuan++;
          if (item.type == 'sisik') sisik++;
          if (item.type == 'cakar') cakar++;
          if (item.type == 'kunci') kunci = true;
        }
      }

      // Flag Goal Check
      if (flagPole != null && player.x > flagPole!.x) {
        loadStage(stage == 1 ? 2 : 1);
      }

      // Fall off Screen
      if (player.y > 350) handleDeath();
    });
  }

  void handleDeath() {
    if (isInvincible) return;
    lives--;
    if (lives > 0) {
      player.x = 50;
      player.y = 100;
      player.dy = 0;
    } else {
      lives = 3;
      ammo = 30;
      loadStage(1);
    }
  }

  void jump() {
    if (player.grounded) {
      player.dy = -400;
      player.grounded = false;
    }
  }

  void shoot() {
    if (ammo > 0) {
      ammo--;
      fireballs.add(Fireball(
        player.x + (player.facingRight ? 30 : -10),
        player.y + 10,
        player.facingRight ? 380 : -380,
      ));
    }
  }

  void useItem(String type) {
    if (type == 'daging' && daging > 0) {
      daging--;
      lives = min(5, lives + 1);
    } else if (type == 'ramuan' && ramuan > 0) {
      ramuan--;
      ammo = min(99, ammo + 20);
    } else if (type == 'sisik' && sisik > 0) {
      sisik--;
      isInvincible = true;
      Future.delayed(const Duration(seconds: 5), () => setState(() => isInvincible = false));
    } else if (type == 'cakar' && cakar > 0) {
      cakar--;
      isDoubleDamage = true;
      Future.delayed(const Duration(seconds: 10), () => setState(() => isDoubleDamage = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 55% Top Screen Game Canvas
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: GamePainter(
                    player: player,
                    platforms: platforms,
                    enemies: enemies,
                    fireballs: fireballs,
                    items: items,
                    flagPole: flagPole,
                    cameraX: cameraX,
                  ),
                ),
                Positioned(
                  top: 10, left: 10, right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("STG: 1-$stage", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                      Row(
                        children: [
                          Text("❤️" * lives, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 12),
                          Text("🔫 $ammo", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 45% Bottom Game Dashboard
          Expanded(
            flex: 45,
            child: Container(
              color: const Color(0xFFD3D3D3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Inventory Bar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _invBtn("🍖", daging, () => useItem('daging')),
                        _invBtn("🧪", ramuan, () => useItem('ramuan')),
                        _invBtn("🛡️", sisik, () => useItem('sisik')),
                        _invBtn("🔥", cakar, () => useItem('cakar')),
                        Text("🔑 ${kunci ? '✅' : '❌'}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),

                  // D-Pad and Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // D-Pad
                      SizedBox(
                        width: 100, height: 100,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0, top: 33,
                              child: _dirBtn(Icons.arrow_left, (down) => keyLeft = down),
                            ),
                            Positioned(
                              right: 0, top: 33,
                              child: _dirBtn(Icons.arrow_right, (down) => keyRight = down),
                            ),
                          ],
                        ),
                      ),

                      // Action Controls (A / B)
                      Row(
                        children: [
                          _actionBtn("B", "FIRE", Colors.redAccent, shoot),
                          const SizedBox(width: 15),
                          _actionBtn("A", "JUMP", const Color(0xFF900C3F), jump),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invBtn(String icon, int val, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(4)),
        child: Text("$icon $val", style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }

  Widget _dirBtn(IconData icon, Function(bool) onPressed) {
    return GestureDetector(
      onTapDown: (_) => onPressed(true),
      onTapUp: (_) => onPressed(false),
      onTapCancel: () => onPressed(false),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _actionBtn(String label, String sub, Color color, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
        ),
        Text(sub, style: const TextStyle(fontSize: 8, color: Colors.black54)),
      ],
    );
  }
}

// ==========================================
// GAME CANVAS PAINTER
// ==========================================
class GamePainter extends CustomPainter {
  final Player player;
  final List<Block> platforms;
  final List<Enemy> enemies;
  final List<Fireball> fireballs;
  final List<Item> items;
  final Block? flagPole;
  final double cameraX;

  GamePainter({
    required this.player,
    required this.platforms,
    required this.enemies,
    required this.fireballs,
    required this.items,
    required this.flagPole,
    required this.cameraX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sky Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF87CEEB));

    canvas.save();
    canvas.translate(-cameraX, 0);

    // Platforms
    for (var p in platforms) {
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, p.h), Paint()..color = const Color(0xFF8B4513));
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, 6), Paint()..color = const Color(0xFF2ECC71));
    }

    // Flag Pole
    if (flagPole != null) {
      canvas.drawRect(Rect.fromLTWH(flagPole!.x, flagPole!.y, flagPole!.w, flagPole!.h), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(flagPole!.x + 10, flagPole!.y, 30, 20), Paint()..color = Colors.red);
    }

    // Items
    for (var item in items) {
      if (item.collected) continue;
      String icon = '🍖';
      if (item.type == 'ramuan') icon = '🧪';
      if (item.type == 'sisik') icon = '🛡️';
      if (item.type == 'cakar') icon = '🔥';
      if (item.type == 'kunci') icon = '🔑';

      final tp = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(item.x, item.y));
    }

    // Enemies
    for (var e in enemies) {
      if (!e.alive) continue;
      canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), Paint()..color = const Color(0xFFCC3300));
    }

    // Fireballs
    for (var fb in fireballs) {
      canvas.drawCircle(Offset(fb.x, fb.y), 5, Paint()..color = Colors.deepOrange);
    }

    // Player Agumon
    canvas.drawRect(Rect.fromLTWH(player.x, player.y + 4, player.w, player.h - 4), Paint()..color = const Color(0xFFFF9900));
    canvas.drawRect(Rect.fromLTWH(player.x + 4, player.y + 10, player.w - 8, player.h - 14), Paint()..color = const Color(0xFFFFCC66));
    canvas.drawRect(
      Rect.fromLTWH(player.facingRight ? player.x + player.w - 6 : player.x + 2, player.y + 6, 4, 6),
      Paint()..color = Colors.black,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
