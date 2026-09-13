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
// GAME MODELS
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
  int jumps = 0;
}

class Block {
  double x, y, w, h;
  Block(this.x, this.y, this.w, this.h);
}

class Pipe {
  double x, y, w, h;
  bool isExit;
  bool isBossPipe;
  Pipe(this.x, this.y, this.w, this.h, {this.isExit = false, this.isBossPipe = false});
}

class Enemy {
  int id;
  double x, y, w, h, dx, minX, maxX;
  String type; // 'walker', 'shield', 'bat'
  bool alive;
  Enemy(this.id, this.x, this.y, this.w, this.h, this.dx, this.minX, this.maxX, {this.type = 'walker', this.alive = true});
}

class Boss {
  double x, y, baseY, w, h, dx, minX, maxX;
  int hp, maxHp;
  bool hasShield;
  double shieldTimer;
  double hoverTime;
  double shootTimer;
  bool alive;
  Boss({
    required this.x,
    required this.y,
    required this.baseY,
    required this.w,
    required this.h,
    required this.dx,
    required this.minX,
    required this.maxX,
    this.hp = 12,
    this.maxHp = 12,
    this.hasShield = true,
    this.shieldTimer = 0,
    this.hoverTime = 0,
    this.shootTimer = 0,
    this.alive = true,
  });
}

class QuestionBlock {
  int id;
  double x, y, w, h;
  String type; // 'ammo', 'heart'
  bool used;
  QuestionBlock(this.id, this.x, this.y, this.w, this.h, this.type, {this.used = false});
}

class Fireball {
  double x, y, dx, dy;
  int bounces;
  bool isBoss;
  Fireball(this.x, this.y, this.dx, {this.dy = 100, this.bounces = 0, this.isBoss = false});
}

class Item {
  int id;
  String type;
  double x, y;
  bool collected;
  Item(this.id, this.type, this.x, this.y, {this.collected = false});
}

class FloatingText {
  String text;
  double x, y;
  double alpha;
  FloatingText(this.text, this.x, this.y, {this.alpha = 1.0});
}

// ==========================================
// MAIN GAME ENGINE & UI
// ==========================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? gameLoopTimer;
  Player player = Player();

  String gameMode = "playing"; // "playing", "banner", "gameover", "win"
  int stage = 1;
  int lives = 3;
  int ammo = 30;
  int maxAmmo = 99;
  int stageCoins = 0;
  double cameraX = 0;
  double shakeTime = 0;

  bool inSecretRoom = false;
  bool inBossLair = false;

  // Inventory
  int daging = 0;
  int ramuan = 0;
  int sisik = 0;
  int cakar = 0;
  bool kunci = false;

  bool isInvincible = false;
  bool isDoubleDamage = false;

  List<Block> platforms = [];
  List<Pipe> secretPipes = [];
  List<Pipe> bossPipes = [];
  List<Enemy> enemies = [];
  List<QuestionBlock> questionBlocks = [];
  List<Fireball> fireballs = [];
  List<Fireball> bossFireballs = [];
  List<Item> items = [];
  List<FloatingText> floatingTexts = [];
  Block? flagPole;
  Boss? boss;

  // Banner State
  String bannerTitle = "";
  String bannerDesc = "";

  // Controls
  bool keyLeft = false;
  bool keyRight = false;
  bool keyDown = false;

  @override
  void initState() {
    super.initState();
    loadStage(1);
    showBanner("STAGE 1-1", "GREEN VALLEY\nPetualangan dimulai! Kumpulkan koin dan item.");
    startGameLoop();
  }

  @override
  void dispose() {
    gameLoopTimer?.cancel();
    super.dispose();
  }

  void showBanner(String title, String desc) {
    setState(() {
      gameMode = "banner";
      bannerTitle = title;
      bannerDesc = desc;
    });
  }

  void closeBanner() {
    setState(() {
      gameMode = "playing";
    });
  }

  void loadStage(int stgNo) {
    stage = stgNo;
    player.x = 50;
    player.y = 150;
    player.dx = 0;
    player.dy = 0;
    inSecretRoom = false;
    inBossLair = false;
    fireballs.clear();
    bossFireballs.clear();
    boss = null;

    if (stage == 1) {
      platforms = [
        Block(0, 220, 900, 50),
        Block(980, 130, 180, 20),
        Block(1240, 70, 200, 20),
        Block(1500, 220, 1000, 50),
      ];
      secretPipes = [Pipe(450, 175, 35, 45)];
      bossPipes = [];
      questionBlocks = [
        QuestionBlock(1, 250, 110, 28, 28, 'ammo'),
        QuestionBlock(2, 1020, 60, 28, 28, 'heart'),
      ];
      enemies = [
        Enemy(101, 600, 194, 26, 26, 80, 520, 680),
        Enemy(102, 750, 194, 26, 26, -70, 680, 820),
        Enemy(103, 1550, 194, 26, 26, 90, 1450, 1650),
        Enemy(104, 1800, 194, 26, 26, -80, 1720, 1880),
      ];
      items = [
        Item(1, 'daging', 350, 180),
        Item(2, 'ramuan', 700, 180),
        Item(3, 'sisik', 1300, 30),
        Item(4, 'kunci', 1900, 180),
      ];
      flagPole = Block(2300, 60, 10, 160);
    } else if (stage == 2) {
      platforms = [
        Block(0, 220, 700, 50),
        Block(780, 120, 200, 20),
        Block(1050, 220, 1200, 50),
      ];
      secretPipes = [Pipe(300, 175, 35, 45)];
      bossPipes = [];
      questionBlocks = [QuestionBlock(3, 820, 60, 28, 28, 'ammo')];
      enemies = [
        Enemy(201, 500, 194, 26, 26, -60, 440, 560, type: 'shield'),
        Enemy(202, 900, 94, 26, 26, 70, 850, 950, type: 'shield'),
        Enemy(203, 1200, 194, 26, 26, 80, 1120, 1280),
        Enemy(204, 1450, 194, 26, 26, -70, 1390, 1510, type: 'shield'),
      ];
      items = [
        Item(5, 'ramuan', 200, 180),
        Item(6, 'cakar', 850, 80),
        Item(7, 'kunci', 1650, 180),
      ];
      flagPole = Block(2000, 60, 10, 160);
    } else if (stage == 3) {
      platforms = [
        Block(0, 220, 600, 50),
        Block(680, 130, 180, 20),
        Block(930, 220, 1200, 50),
      ];
      secretPipes = [Pipe(250, 175, 35, 45)];
      bossPipes = [Pipe(1800, 165, 45, 55, isBossPipe: true)];
      questionBlocks = [QuestionBlock(4, 740, 80, 28, 28, 'ammo')];
      enemies = [
        Enemy(301, 500, 120, 24, 20, 90, 420, 580, type: 'bat'),
        Enemy(302, 750, 70, 24, 20, -100, 680, 820, type: 'bat'),
        Enemy(303, 1100, 140, 24, 20, 110, 1010, 1190, type: 'bat'),
      ];
      items = [];
      flagPole = null;
    }
  }

  void enterSecretRoom() {
    setState(() {
      inSecretRoom = true;
      platforms = [
        Block(0, 220, 700, 50),
        Block(150, 170, 80, 15),
        Block(300, 120, 80, 15),
      ];
      enemies = [];
      questionBlocks = [];
      bossPipes = [];
      secretPipes = [Pipe(600, 175, 35, 45, isExit: true)];
      items = [Item(99, 'kristal', 330, 90)];
      player.x = 30;
      player.y = 100;
    });
  }

  void enterBossLair() {
    setState(() {
      inBossLair = true;
      platforms = [
        Block(0, 220, 800, 50),
        Block(80, 110, 110, 20),
        Block(610, 110, 110, 20),
      ];
      enemies = [];
      questionBlocks = [];
      secretPipes = [];
      bossPipes = [];
      items = [];
      boss = Boss(
        x: 660,
        y: 50,
        baseY: 50,
        w: 60,
        h: 54,
        dx: -110,
        minX: 80,
        maxX: 710,
      );
      flagPole = null;
      player.x = 40;
      player.y = 150;
      showBanner("DRAGON'S NEST", "Arena Terkunci! Naga Penjaga MetalGreymon menghadang!");
    });
  }

  void startGameLoop() {
    gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (gameMode == "playing") {
        updatePhysics(0.016);
      }
    });
  }

  void triggerShake(double duration) {
    shakeTime = duration;
  }

  void updatePhysics(double dt) {
    setState(() {
      if (shakeTime > 0) shakeTime -= dt;

      // Horizontal Movement
      if (keyLeft) {
        player.dx = -160;
        player.facingRight = false;
      } else if (keyRight) {
        player.dx = 160;
        player.facingRight = true;
      } else {
        player.dx *= 0.8;
      }

      player.x += player.dx * dt;

      // Gravity & Jump Physics
      player.dy += 950 * dt;
      if (player.dy > 600) player.dy = 600;
      player.y += player.dy * dt;

      // Platform Collision
      player.grounded = false;
      for (var p in platforms) {
        if (player.x < p.x + p.w &&
            player.x + player.w > p.x &&
            player.y < p.y + p.h &&
            player.y + player.h > p.y) {
          if (player.dy >= 0 && player.y + player.h - player.dy * dt <= p.y + 15) {
            player.y = p.y - player.h;
            player.dy = 0;
            player.grounded = true;
            player.jumps = 0;
          }
        }
      }

      // Camera Follow
      cameraX = inBossLair ? 0 : max(0, player.x - 120);

      // Secret & Boss Pipes Interactions
      for (var sp in secretPipes) {
        if (keyDown &&
            player.x + player.w > sp.x &&
            player.x < sp.x + sp.w &&
            (player.y + player.h - sp.y).abs() < 10) {
          if (sp.isExit) {
            inSecretRoom = false;
            loadStage(stage);
          } else {
            enterSecretRoom();
          }
        }
      }

      for (var bp in bossPipes) {
        if (keyDown &&
            player.x + player.w > bp.x &&
            player.x < bp.x + bp.w &&
            (player.y + player.h - bp.y).abs() < 10) {
          if (kunci) {
            enterBossLair();
          } else {
            floatingTexts.add(FloatingText("BUTUH KUNCI!", player.x, player.y - 10));
          }
        }
      }

      // Question Blocks Interaction
      for (var qb in questionBlocks) {
        if (!qb.used &&
            player.x < qb.x + qb.w &&
            player.x + player.w > qb.x &&
            player.y < qb.y + qb.h &&
            player.y + player.h > qb.y) {
          if (player.dy < 0) {
            qb.used = true;
            if (qb.type == 'ammo') ammo = min(maxAmmo, ammo + 10);
            if (qb.type == 'heart') lives = min(5, lives + 1);
          }
        }
      }

      // Items Collection
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

      // Enemy Physics & AI
      for (var e in enemies) {
        if (!e.alive) continue;
        e.x += e.dx * dt;
        if (e.x < e.minX || e.x > e.maxX) e.dx *= -1;

        if (player.x < e.x + e.w &&
            player.x + player.w > e.x &&
            player.y < e.y + e.h &&
            player.y + player.h > e.y) {
          handleDeath();
        }
      }

      // Fireballs Movement
      for (int i = fireballs.length - 1; i >= 0; i--) {
        var fb = fireballs[i];
        fb.x += fb.dx * dt;
        fb.dy += 950 * dt * 0.4;
        fb.y += fb.dy * dt;

        if (fb.y > 210) {
          fb.y = 210;
          fb.bounces++;
          if (fb.bounces <= 1) {
            fb.dy = -180;
          } else {
            fireballs.removeAt(i);
            continue;
          }
        }

        // Hit Enemies
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

      // Boss Logic & AI
      if (boss != null && boss!.alive) {
        double speedMult = (boss!.hp < boss!.maxHp / 2) ? 1.5 : 1.0;
        boss!.hoverTime += dt;
        boss!.x += boss!.dx * speedMult * dt;
        if (boss!.x < boss!.minX || boss!.x > boss!.maxX) boss!.dx *= -1;
        boss!.y = boss!.baseY + sin(boss!.hoverTime * 2.5 * speedMult) * 25;

        if (!boss!.hasShield) {
          boss!.shieldTimer -= dt;
          if (boss!.shieldTimer <= 0) boss!.hasShield = true;
        }

        // Boss Shoot
        boss!.shootTimer += dt;
        if (boss!.shootTimer > (2.1 / speedMult)) {
          double pCX = player.x + player.w / 2;
          double pCY = player.y + player.h / 2;
          double bCX = boss!.x + boss!.w / 2;
          double bCY = boss!.y + boss!.h;
          double angle = atan2(pCY - bCY, pCX - bCX);
          bossFireballs.add(Fireball(bCX - 5, bCY, cos(angle) * 180, dy: sin(angle) * 180, isBoss: true));
          boss!.shootTimer = 0;
        }

        // Boss Touch Hit Player
        if (player.x < boss!.x + boss!.w &&
            player.x + player.w > boss!.x &&
            player.y < boss!.y + boss!.h &&
            player.y + player.h > boss!.y) {
          handleDeath();
        }

        // Player Fireball Hits Boss
        for (int i = fireballs.length - 1; i >= 0; i--) {
          var fb = fireballs[i];
          if (fb.x < boss!.x + boss!.w &&
              fb.x + 10 > boss!.x &&
              fb.y < boss!.y + boss!.h &&
              fb.y + 10 > boss!.y) {
            fireballs.removeAt(i);
            if (boss!.hasShield) {
              boss!.hasShield = false;
              boss!.shieldTimer = 3.0;
              triggerShake(0.1);
            } else {
              int dmg = isDoubleDamage ? 2 : 1;
              boss!.hp -= dmg;
              boss!.hasShield = true;
              boss!.shieldTimer = 0;
              triggerShake(0.3);
              if (boss!.hp <= 0) {
                boss!.alive = false;
                flagPole = Block(400, 60, 10, 160);
              }
            }
            break;
          }
        }
      }

      // Boss Fireballs Hit Player
      for (int i = bossFireballs.length - 1; i >= 0; i--) {
        var bfb = bossFireballs[i];
        bfb.x += bfb.dx * dt;
        bfb.y += bfb.dy * dt;
        if (player.x < bfb.x + 10 &&
            player.x + player.w > bfb.x &&
            player.y < bfb.y + 10 &&
            player.y + player.h > bfb.y) {
          bossFireballs.removeAt(i);
          handleDeath();
        } else if (bfb.x < -50 || bfb.x > 850 || bfb.y > 350) {
          bossFireballs.removeAt(i);
        }
      }

      // Floating Texts animation
      for (int i = floatingTexts.length - 1; i >= 0; i--) {
        var ft = floatingTexts[i];
        ft.y -= 20 * dt;
        ft.alpha -= 0.8 * dt;
        if (ft.alpha <= 0) floatingTexts.removeAt(i);
      }

      // Stage Flag Completion
      if (flagPole != null && player.x > flagPole!.x) {
        if (stage == 1) {
          loadStage(2);
          showBanner("STAGE 1-2: TOXIC SEWER", "Udaranya beracun. Waspada musuh bertameng!");
        } else if (stage == 2) {
          loadStage(3);
          showBanner("STAGE 1-3: HELL LAVA", "Cari pipa merah menuju arena Bos!");
        } else {
          gameMode = "win";
        }
      }

      // Death by Falling
      if (player.y > 350) handleDeath();
    });
  }

  void handleDeath() {
    if (isInvincible) return;
    lives--;
    triggerShake(0.3);
    if (lives > 0) {
      if (inBossLair) {
        enterBossLair();
      } else {
        player.x = 50;
        player.y = 100;
        player.dy = 0;
      }
    } else {
      gameMode = "gameover";
    }
  }

  void jump() {
    if (gameMode == "banner") {
      closeBanner();
      return;
    }
    if (gameMode == "gameover" || gameMode == "win") {
      lives = 3;
      ammo = 30;
      loadStage(1);
      showBanner("STAGE 1-1", "GREEN VALLEY\nPetualangan dimulai kembali!");
      return;
    }
    if (player.grounded || player.jumps < 2) {
      player.dy = -380;
      player.grounded = false;
      player.jumps++;
    }
  }

  void shoot() {
    if (gameMode != "playing") return;
    if (ammo > 0) {
      ammo--;
      fireballs.add(Fireball(
        player.x + (player.facingRight ? 30 : -10),
        player.y + 12,
        player.facingRight ? 420 : -420,
      ));
    }
  }

  void useItem(String type) {
    if (type == 'daging' && daging > 0) {
      daging--;
      lives = min(5, lives + 1);
      floatingTexts.add(FloatingText("+1 HP", player.x, player.y - 10));
    } else if (type == 'ramuan' && ramuan > 0) {
      ramuan--;
      ammo = min(maxAmmo, ammo + 20);
      floatingTexts.add(FloatingText("+20 AMMO", player.x, player.y - 10));
    } else if (type == 'sisik' && sisik > 0) {
      sisik--;
      isInvincible = true;
      floatingTexts.add(FloatingText("KEBAL 5s!", player.x, player.y - 10));
      Future.delayed(const Duration(seconds: 5), () => setState(() => isInvincible = false));
    } else if (type == 'cakar' && cakar > 0) {
      cakar--;
      isDoubleDamage = true;
      floatingTexts.add(FloatingText("2X DMG!", player.x, player.y - 10));
      Future.delayed(const Duration(seconds: 10), () => setState(() => isDoubleDamage = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Upper Canvas Frame (55%)
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: GamePainter(
                    player: player,
                    platforms: platforms,
                    secretPipes: secretPipes,
                    bossPipes: bossPipes,
                    enemies: enemies,
                    questionBlocks: questionBlocks,
                    fireballs: fireballs,
                    bossFireballs: bossFireballs,
                    items: items,
                    floatingTexts: floatingTexts,
                    flagPole: flagPole,
                    boss: boss,
                    cameraX: cameraX,
                    shakeTime: shakeTime,
                    stage: stage,
                    inSecretRoom: inSecretRoom,
                    inBossLair: inBossLair,
                  ),
                ),
                Positioned(
                  top: 10, left: 10, right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("STG: 1-$stage", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                      Row(
                        children: [
                          Text("❤️" * lives, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 10),
                          Text("🔫 $ammo", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
                if (gameMode == "banner")
                  Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(bannerTitle, style: const TextStyle(color: Color(0xFFF1C40F), fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(bannerDesc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9)),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: closeBanner,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
                          child: const Text("LANJUT (A)", style: TextStyle(fontSize: 9, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                if (gameMode == "gameover" || gameMode == "win")
                  Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gameMode == "win" ? "LUAR BIASA! TAMAT!" : "GAME OVER", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        const Text("Tekan Tombol A untuk Mulai Lagi", style: TextStyle(color: Colors.white70, fontSize: 8)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Lower Control Dashboard (45%)
          Expanded(
            flex: 45,
            child: Container(
              color: const Color(0xFFD3D3D3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                            Positioned(
                              left: 33, bottom: 0,
                              child: _dirBtn(Icons.arrow_drop_down, (down) => keyDown = down),
                            ),
                          ],
                        ),
                      ),
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
            width: 44, height: 44,
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
// GAME PAINTER (CANVAS DRAWING)
// ==========================================
class GamePainter extends CustomPainter {
  final Player player;
  final List<Block> platforms;
  final List<Pipe> secretPipes;
  final List<Pipe> bossPipes;
  final List<Enemy> enemies;
  final List<QuestionBlock> questionBlocks;
  final List<Fireball> fireballs;
  final List<Fireball> bossFireballs;
  final List<Item> items;
  final List<FloatingText> floatingTexts;
  final Block? flagPole;
  final Boss? boss;
  final double cameraX;
  final double shakeTime;
  final int stage;
  final bool inSecretRoom;
  final bool inBossLair;

  GamePainter({
    required this.player,
    required this.platforms,
    required this.secretPipes,
    required this.bossPipes,
    required this.enemies,
    required this.questionBlocks,
    required this.fireballs,
    required this.bossFireballs,
    required this.items,
    required this.floatingTexts,
    required this.flagPole,
    required this.boss,
    required this.cameraX,
    required this.shakeTime,
    required this.stage,
    required this.inSecretRoom,
    required this.inBossLair,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sky Background Dynamic Color
    Color skyColor = const Color(0xFF87CEEB);
    if (inSecretRoom) skyColor = Colors.black;
    if (inBossLair) skyColor = const Color(0xFF4A0000);
    if (stage == 2 && !inSecretRoom) skyColor = const Color(0xFF0A2F1D);
    if (stage == 3 && !inBossLair) skyColor = const Color(0xFF2B0000);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = skyColor);

    canvas.save();
    double offsetX = (shakeTime > 0) ? (Random().nextDouble() - 0.5) * 8 : 0;
    double offsetY = (shakeTime > 0) ? (Random().nextDouble() - 0.5) * 8 : 0;
    canvas.translate(-cameraX + offsetX, offsetY);

    // Platforms
    for (var p in platforms) {
      Color platformColor = const Color(0xFF8B4513);
      Color topColor = const Color(0xFF2ECC71);
      if (stage == 2) {
        platformColor = const Color(0xFF1C2833);
        topColor = const Color(0xFF27AE60);
      } else if (stage == 3 || inBossLair) {
        platformColor = const Color(0xFF1A0000);
        topColor = const Color(0xFFFF3300);
      }
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, p.h), Paint()..color = platformColor);
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, 6), Paint()..color = topColor);
    }

    // Pipes
    for (var sp in secretPipes) {
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, sp.w, sp.h), Paint()..color = const Color(0xFF1E8449));
      canvas.drawRect(Rect.fromLTWH(sp.x - 3, sp.y, sp.w + 6, 10), Paint()..color = const Color(0xFF27AE60));
    }
    for (var bp in bossPipes) {
      canvas.drawRect(Rect.fromLTWH(bp.x, bp.y, bp.w, bp.h), Paint()..color = const Color(0xFFC0392B));
      canvas.drawRect(Rect.fromLTWH(bp.x - 3, bp.y, bp.w + 6, 10), Paint()..color = const Color(0xFFE74C3C));
    }

    // Question Blocks
    for (var qb in questionBlocks) {
      canvas.drawRect(Rect.fromLTWH(qb.x, qb.y, qb.w, qb.h), Paint()..color = qb.used ? Colors.grey : const Color(0xFFF39C12));
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
      if (item.type == 'kristal') icon = '💎';

      final tp = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(item.x, item.y));
    }

    // Enemies
    for (var e in enemies) {
      if (!e.alive) continue;
      Color enemyColor = const Color(0xFFCC3300);
      if (e.type == 'shield') enemyColor = const Color(0xFF34495E);
      if (e.type == 'bat') enemyColor = const Color(0xFF76B900);
      canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), Paint()..color = enemyColor);
    }

    // Boss MetalGreymon
    if (boss != null && boss!.alive) {
      canvas.drawRect(Rect.fromLTWH(boss!.x, boss!.y, boss!.w, boss!.h), Paint()..color = const Color(0xFF922B21));
      if (boss!.hasShield) {
        canvas.drawRect(
          Rect.fromLTWH(boss!.x - 4, boss!.y - 4, boss!.w + 8, boss!.h + 8),
          Paint()
            ..color = Colors.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawRect(Rect.fromLTWH(boss!.x, boss!.y - 10, (boss!.hp / boss!.maxHp) * boss!.w, 5), Paint()..color = Colors.red);
    }

    // Fireballs
    for (var fb in fireballs) {
      canvas.drawCircle(Offset(fb.x, fb.y), 5, Paint()..color = Colors.deepOrange);
    }
    for (var bfb in bossFireballs) {
      canvas.drawCircle(Offset(bfb.x, bfb.y), 6, Paint()..color = Colors.purpleAccent);
    }

    // Player Agumon
    canvas.drawRect(Rect.fromLTWH(player.x, player.y + 4, player.w, player.h - 4), Paint()..color = const Color(0xFFFF9900));
    canvas.drawRect(Rect.fromLTWH(player.x + 4, player.y + 10, player.w - 8, player.h - 14), Paint()..color = const Color(0xFFFFCC66));
    canvas.drawRect(
      Rect.fromLTWH(player.facingRight ? player.x + player.w - 6 : player.x + 2, player.y + 6, 4, 6),
      Paint()..color = Colors.black,
    );

    // Floating Texts
    for (var ft in floatingTexts) {
      final tp = TextPainter(
        text: TextSpan(text: ft.text, style: TextStyle(color: Colors.yellow.withOpacity(max(0, ft.alpha)), fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ft.x, ft.y));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
