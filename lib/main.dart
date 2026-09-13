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
      title: 'Super Mario Strategy - Digimon Ultimate',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

// ==========================================
// GAME MODELS & PARTICLES
// ==========================================
class Player {
  double x = 50;
  double y = 100;
  double baseW = 28;
  double baseH = 32;
  double dx = 0;
  double dy = 0;
  bool grounded = false;
  bool facingRight = true;
  int jumps = 0;

  bool isEvolved = false;
  double evolveTimer = 0;

  double get w => isEvolved ? baseW * 1.5 : baseW;
  double get h => isEvolved ? baseH * 1.5 : baseH;
}

class Particle {
  double x, y, dx, dy;
  Color color;
  double size;
  double life;
  Particle(this.x, this.y, this.dx, this.dy, this.color, this.size, {this.life = 1.0});
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
  double x, y, baseY, w, h, dx, minX, maxX;
  String type;
  double animTimer = 0;
  bool alive;
  Enemy(this.id, this.x, this.y, this.w, this.h, this.dx, this.minX, this.maxX, {this.type = 'walker', this.alive = true})
      : baseY = y;
}

class Boss {
  double x, y, baseY, w, h, dx, minX, maxX;
  int hp, maxHp;
  bool hasShield;
  double shieldTimer;
  double hoverTime;
  double shootTimer;
  bool isEnraged = false;
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
    this.hp = 14,
    this.maxHp = 14,
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
  String type;
  bool used;
  QuestionBlock(this.id, this.x, this.y, this.w, this.h, this.type, {this.used = false});
}

class Fireball {
  double x, y, dx, dy;
  int bounces;
  bool isBoss;
  bool isMegaFlame;
  Fireball(this.x, this.y, this.dx, this.dy, {this.bounces = 0, this.isBoss = false, this.isMegaFlame = false});
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

  String gameMode = "playing";
  int stage = 1;
  int lives = 3;
  int ammo = 30;
  int maxAmmo = 99;
  int score = 0;
  int highScore = 0;
  double cameraX = 0;
  double shakeTime = 0;

  bool inSecretRoom = false;
  bool inBossLair = false;

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
  List<Particle> particles = [];
  List<Item> items = [];
  List<FloatingText> floatingTexts = [];
  Block? flagPole;
  Boss? boss;

  String bannerTitle = "";
  String bannerDesc = "";

  bool keyLeft = false;
  bool keyRight = false;
  bool keyUp = false;
  bool keyDown = false;

  @override
  void initState() {
    super.initState();
    loadStage(1);
    showBanner("STAGE 1-1", "GREEN VALLEY\nPetualangan dimulai! Ambil Kristal Crest untuk Evolusi Greymon!");
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

  void togglePause() {
    setState(() {
      if (gameMode == "playing") {
        gameMode = "paused";
      } else if (gameMode == "paused") {
        gameMode = "playing";
      }
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
    particles.clear();
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
      showBanner("DRAGON'S NEST", "Arena Terkunci! MetalGreymon Siap Bertarung!");
    });
  }

  void startGameLoop() {
    gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (gameMode == "playing") {
        updatePhysics(0.016);
      }
    });
  }

  void spawnExplosion(double x, double y, Color color, {int count = 8}) {
    for (int i = 0; i < count; i++) {
      double angle = Random().nextDouble() * 2 * pi;
      double speed = 40 + Random().nextDouble() * 80;
      particles.add(Particle(
        x, y,
        cos(angle) * speed,
        sin(angle) * speed,
        color,
        2 + Random().nextDouble() * 3,
      ));
    }
  }

  void triggerShake(double duration) {
    shakeTime = duration;
  }

  void evolveToGreymon() {
    setState(() {
      player.isEvolved = true;
      player.evolveTimer = 15.0;
      floatingTexts.add(FloatingText("EVOLUSI GREYMON!!", player.x, player.y - 20));
      spawnExplosion(player.x, player.y, Colors.orange, count: 20);
    });
  }

  void updatePhysics(double dt) {
    setState(() {
      if (shakeTime > 0) shakeTime -= dt;

      if (player.isEvolved) {
        player.evolveTimer -= dt;
        if (player.evolveTimer <= 0) {
          player.isEvolved = false;
          floatingTexts.add(FloatingText("KEMBALI KE AGUMON", player.x, player.y - 10));
        }
      }

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
      player.dy += 950 * dt;
      if (player.dy > 600) player.dy = 600;
      player.y += player.dy * dt;

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

      cameraX = inBossLair ? 0 : max(0, player.x - 120);

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

      for (var qb in questionBlocks) {
        if (!qb.used &&
            player.x < qb.x + qb.w &&
            player.x + player.w > qb.x &&
            player.y < qb.y + qb.h &&
            player.y + player.h > qb.y) {
          if (player.dy < 0) {
            qb.used = true;
            spawnExplosion(qb.x + 14, qb.y + 14, Colors.yellow, count: 6);
            if (qb.type == 'ammo') ammo = min(maxAmmo, ammo + 10);
            if (qb.type == 'heart') lives = min(5, lives + 1);
          }
        }
      }

      for (var item in items) {
        if (!item.collected &&
            player.x < item.x + 20 &&
            player.x + player.w > item.x &&
            player.y < item.y + 20 &&
            player.y + player.h > item.y) {
          item.collected = true;
          spawnExplosion(item.x, item.y, Colors.amber);
          if (item.type == 'daging') daging++;
          if (item.type == 'ramuan') ramuan++;
          if (item.type == 'sisik') sisik++;
          if (item.type == 'cakar') cakar++;
          if (item.type == 'kunci') kunci = true;
          if (item.type == 'kristal') evolveToGreymon();
        }
      }

      for (var e in enemies) {
        if (!e.alive) continue;
        e.x += e.dx * dt;
        if (e.x < e.minX || e.x > e.maxX) e.dx *= -1;

        if (e.type == 'bat') {
          e.animTimer += dt * 4;
          e.y = e.baseY + sin(e.animTimer) * 20;
        }

        if (player.x < e.x + e.w &&
            player.x + player.w > e.x &&
            player.y < e.y + e.h &&
            player.y + player.h > e.y) {
          handleDeath();
        }
      }

      for (int i = fireballs.length - 1; i >= 0; i--) {
        var fb = fireballs[i];
        fb.x += fb.dx * dt;
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

        double fbSize = fb.isMegaFlame ? 16 : 8;
        for (var e in enemies) {
          if (e.alive &&
              fb.x < e.x + e.w &&
              fb.x + fbSize > e.x &&
              fb.y < e.y + e.h &&
              fb.y + fbSize > e.y) {
            e.alive = false;
            score += 100;
            if (score > highScore) highScore = score;
            spawnExplosion(e.x + 10, e.y + 10, Colors.deepOrange, count: 12);
            fireballs.removeAt(i);
            break;
          }
        }
      }

      if (boss != null && boss!.alive) {
        boss!.isEnraged = boss!.hp <= (boss!.maxHp / 2);
        double speedMult = boss!.isEnraged ? 1.8 : 1.0;

        boss!.hoverTime += dt;
        boss!.x += boss!.dx * speedMult * dt;
        if (boss!.x < boss!.minX || boss!.x > boss!.maxX) boss!.dx *= -1;
        boss!.y = boss!.baseY + sin(boss!.hoverTime * 2.5 * speedMult) * 25;

        if (!boss!.hasShield) {
          boss!.shieldTimer -= dt;
          if (boss!.shieldTimer <= 0) boss!.hasShield = true;
        }

        boss!.shootTimer += dt;
        double cooldown = boss!.isEnraged ? 1.2 : 2.1;
        if (boss!.shootTimer > cooldown) {
          double pCX = player.x + player.w / 2;
          double pCY = player.y + player.h / 2;
          double bCX = boss!.x + boss!.w / 2;
          double bCY = boss!.y + boss!.h;
          double angle = atan2(pCY - bCY, pCX - bCX);
          bossFireballs.add(Fireball(bCX - 5, bCY, cos(angle) * 200, sin(angle) * 200, isBoss: true));

          if (boss!.isEnraged) {
            bossFireballs.add(Fireball(bCX - 5, bCY, cos(angle + 0.3) * 200, sin(angle + 0.3) * 200, isBoss: true));
          }
          boss!.shootTimer = 0;
        }

        if (player.x < boss!.x + boss!.w &&
            player.x + player.w > boss!.x &&
            player.y < boss!.y + boss!.h &&
            player.y + player.h > boss!.y) {
          handleDeath();
        }

        for (int i = fireballs.length - 1; i >= 0; i--) {
          var fb = fireballs[i];
          double fbSize = fb.isMegaFlame ? 16 : 8;
          if (fb.x < boss!.x + boss!.w &&
              fb.x + fbSize > boss!.x &&
              fb.y < boss!.y + boss!.h &&
              fb.y + fbSize > boss!.y) {
            fireballs.removeAt(i);
            if (boss!.hasShield) {
              boss!.hasShield = false;
              boss!.shieldTimer = 3.0;
              spawnExplosion(boss!.x + 30, boss!.y + 20, Colors.cyan, count: 10);
              triggerShake(0.1);
            } else {
              int dmg = (isDoubleDamage || player.isEvolved) ? 2 : 1;
              boss!.hp -= dmg;
              boss!.hasShield = true;
              boss!.shieldTimer = 0;
              spawnExplosion(boss!.x + 30, boss!.y + 20, Colors.red, count: 15);
              triggerShake(0.3);
              if (boss!.hp <= 0) {
                boss!.alive = false;
                score += 1000;
                if (score > highScore) highScore = score;
                flagPole = Block(400, 60, 10, 160);
              }
            }
            break;
          }
        }
      }

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

      for (int i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.dx * dt;
        p.y += p.dy * dt;
        p.life -= 2.0 * dt;
        if (p.life <= 0) particles.removeAt(i);
      }

      for (int i = floatingTexts.length - 1; i >= 0; i--) {
        var ft = floatingTexts[i];
        ft.y -= 20 * dt;
        ft.alpha -= 0.8 * dt;
        if (ft.alpha <= 0) floatingTexts.removeAt(i);
      }

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

      if (player.y > 350) handleDeath();
    });
  }

  void handleDeath() {
    if (isInvincible) return;
    lives--;
    triggerShake(0.3);
    spawnExplosion(player.x, player.y, Colors.orange, count: 15);
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
    HapticFeedback.lightImpact();
    if (gameMode == "banner") {
      closeBanner();
      return;
    }
    if (gameMode == "gameover" || gameMode == "win") {
      lives = 3;
      ammo = 30;
      score = 0;
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
    HapticFeedback.lightImpact();
    if (gameMode != "playing") return;
    if (ammo > 0) {
      ammo--;
      double fdx = player.facingRight ? 420 : -420;
      double fdy = 0;
      if (keyUp) {
        fdy = -300;
        fdx *= 0.7;
      }
      fireballs.add(Fireball(
        player.x + (player.facingRight ? player.w : -10),
        player.y + 12,
        fdx, fdy,
        isMegaFlame: player.isEvolved,
      ));
    }
  }

  void useItem(String type) {
    HapticFeedback.mediumImpact();
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
                    particles: particles,
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
                  top: 8, left: 10, right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("STG: 1-$stage", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          const SizedBox(width: 15),
                          Text("SCORE: $score", style: const TextStyle(color: Colors.yellow, fontSize: 10, fontFamily: 'monospace')),
                        ],
                      ),
                      Row(
                        children: [
                          Text("❤️" * lives, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 10),
                          Text("🔫 $ammo", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(gameMode == "paused" ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 16),
                            onPressed: togglePause,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (gameMode == "paused")
                  Container(
                    color: Colors.black.withOpacity(0.75),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("GAME PAUSED", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: togglePause,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                          child: const Text("LANJUTKAN", style: TextStyle(fontSize: 9, color: Colors.white)),
                        )
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
                        const SizedBox(height: 6),
                        Text("HIGH SCORE: $highScore", style: const TextStyle(color: Colors.yellow, fontSize: 9)),
                        const SizedBox(height: 10),
                        const Text("Tekan Tombol A untuk Mulai Lagi", style: TextStyle(color: Colors.white70, fontSize: 8)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD3D3D3),
                border: Border(top: BorderSide(color: Color(0xFFBBBBBB), width: 4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade700)),
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
                        width: 105, height: 105,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 35, top: 0,
                              child: _dirBtn(Icons.arrow_drop_up, (down) => keyUp = down),
                            ),
                            Positioned(
                              left: 0, top: 35,
                              child: _dirBtn(Icons.arrow_left, (down) => keyLeft = down),
                            ),
                            Positioned(
                              right: 0, top: 35,
                              child: _dirBtn(Icons.arrow_right, (down) => keyRight = down),
                            ),
                            Positioned(
                              left: 35, bottom: 0,
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
        decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
        child: Text("$icon $val", style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }

  Widget _dirBtn(IconData icon, Function(bool) onPressed) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        onPressed(true);
      },
      onTapUp: (_) => onPressed(false),
      onTapCancel: () => onPressed(false),
      child: Container(
        width: 35, height: 35,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
            ),
            child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 7, color: Colors.black54, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ==========================================
// GAME PAINTER (AUTOMATIC GRAPHICS & PARTICLES)
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
  final List<Particle> particles;
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
    required this.particles,
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
    Color skyTop = const Color(0xFF2C3E50);
    Color skyBottom = const Color(0xFF3498DB);
    if (inSecretRoom) {
      skyTop = Colors.black;
      skyBottom = const Color(0xFF111111);
    } else if (inBossLair) {
      skyTop = const Color(0xFF4A0000);
      skyBottom = const Color(0xFF1A0000);
    } else if (stage == 2) {
      skyTop = const Color(0xFF0A2F1D);
      skyBottom = const Color(0xFF113823);
    } else if (stage == 3) {
      skyTop = const Color(0xFF2B0000);
      skyBottom = const Color(0xFF800000);
    }

    final bgPaint = Paint()
      ..shader = LinearGradient(colors: [skyTop, skyBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    canvas.save();
    double offsetX = (shakeTime > 0) ? (Random().nextDouble() - 0.5) * 8 : 0;
    double offsetY = (shakeTime > 0) ? (Random().nextDouble() - 0.5) * 8 : 0;
    canvas.translate(-cameraX + offsetX, offsetY);

    for (var p in platforms) {
      Color bodyColor = const Color(0xFF8B4513);
      Color topColor = const Color(0xFF2ECC71);
      if (stage == 2) {
        bodyColor = const Color(0xFF1C2833);
        topColor = const Color(0xFF27AE60);
      } else if (stage == 3 || inBossLair) {
        bodyColor = const Color(0xFF1A0000);
        topColor = const Color(0xFFFF3300);
      }
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, p.h), Paint()..color = bodyColor);
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, 6), Paint()..color = topColor);
    }

    void drawPipe(Pipe pipe, Color mainColor, Color topColor) {
      canvas.drawRect(Rect.fromLTWH(pipe.x, pipe.y, pipe.w, pipe.h), Paint()..color = mainColor);
      canvas.drawRect(Rect.fromLTWH(pipe.x - 3, pipe.y, pipe.w + 6, 10), Paint()..color = topColor);
      canvas.drawRect(Rect.fromLTWH(pipe.x + 4, pipe.y, 4, pipe.h), Paint()..color = Colors.white24);
    }

    for (var sp in secretPipes) {
      drawPipe(sp, const Color(0xFF1E8449), const Color(0xFF27AE60));
    }
    for (var bp in bossPipes) {
      drawPipe(bp, const Color(0xFFC0392B), const Color(0xFFE74C3C));
    }

    for (var qb in questionBlocks) {
      canvas.drawRect(Rect.fromLTWH(qb.x, qb.y, qb.w, qb.h), Paint()..color = qb.used ? Colors.grey : const Color(0xFFF39C12));
      if (!qb.used) {
        final tp = TextPainter(
          text: const TextSpan(text: '?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(qb.x + 7, qb.y + 3));
      }
    }

    if (flagPole != null) {
      canvas.drawRect(Rect.fromLTWH(flagPole!.x, flagPole!.y, flagPole!.w, flagPole!.h), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(flagPole!.x + 10, flagPole!.y, 30, 20), Paint()..color = Colors.red);
    }

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

    for (var e in enemies) {
      if (!e.alive) continue;
      if (e.type == 'shield') {
        canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), Paint()..color = const Color(0xFF34495E));
        canvas.drawRect(Rect.fromLTWH(e.x + (e.dx > 0 ? e.w - 4 : 0), e.y, 4, e.h), Paint()..color = const Color(0xFFBDC3C7));
      } else if (e.type == 'bat') {
        canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), Paint()..color = const Color(0xFF76B900));
        canvas.drawRect(Rect.fromLTWH(e.x - 6, e.y + 4, 6, 4), Paint()..color = const Color(0xFFCCFF00));
        canvas.drawRect(Rect.fromLTWH(e.x + e.w, e.y + 4, 6, 4), Paint()..color = const Color(0xFFCCFF00));
      } else {
        canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h), Paint()..color = const Color(0xFFCC3300));
      }
    }

    if (boss != null && boss!.alive) {
      Color bossBody = boss!.isEnraged ? Colors.red.shade900 : const Color(0xFF922B21);
      canvas.drawRect(Rect.fromLTWH(boss!.x - 12, boss!.y + 10, 12, 20), Paint()..color = Colors.blueGrey);
      canvas.drawRect(Rect.fromLTWH(boss!.x + boss!.w, boss!.y + 10, 12, 20), Paint()..color = Colors.blueGrey);
      canvas.drawRect(Rect.fromLTWH(boss!.x, boss!.y, boss!.w, boss!.h), Paint()..color = bossBody);

      if (boss!.hasShield) {
        canvas.drawRect(
          Rect.fromLTWH(boss!.x - 6, boss!.y - 6, boss!.w + 12, boss!.h + 12),
          Paint()
            ..color = Colors.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawRect(Rect.fromLTWH(boss!.x, boss!.y - 12, boss!.w, 5), Paint()..color = Colors.black);
      canvas.drawRect(Rect.fromLTWH(boss!.x, boss!.y - 12, (boss!.hp / boss!.maxHp) * boss!.w, 5), Paint()..color = Colors.red);
    }

    for (var fb in fireballs) {
      double r = fb.isMegaFlame ? 10 : 5;
      Color fColor = fb.isMegaFlame ? Colors.yellow : Colors.deepOrange;
      canvas.drawCircle(Offset(fb.x, fb.y), r, Paint()..color = fColor);
    }
    for (var bfb in bossFireballs) {
      canvas.drawCircle(Offset(bfb.x, bfb.y), 6, Paint()..color = Colors.purpleAccent);
    }

    for (var pt in particles) {
      canvas.drawCircle(Offset(pt.x, pt.y), pt.size, Paint()..color = pt.color.withOpacity(max(0, pt.life)));
    }

    double px = player.x;
    double py = player.y;
    double pw = player.w;
    double ph = player.h;

    Color skinColor = player.isEvolved ? const Color(0xFFE67E22) : const Color(0xFFFF9900);
    canvas.drawRect(Rect.fromLTWH(px, py + 4, pw, ph - 4), Paint()..color = skinColor);
    canvas.drawRect(Rect.fromLTWH(px + 4, py + 12, pw - 8, ph - 16), Paint()..color = const Color(0xFFFFCC66));
    canvas.drawRect(
      Rect.fromLTWH(player.facingRight ? px + pw - 6 : px + 2, py + 6, 4, 6),
      Paint()..color = Colors.black,
    );

    if (player.isEvolved) {
      canvas.drawRect(Rect.fromLTWH(px + (player.facingRight ? pw - 4 : -4), py - 6, 8, 8), Paint()..color = Colors.blueGrey);
    }

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
