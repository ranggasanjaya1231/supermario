import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';

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
// GAME ENGINE MAIN CLASS
// ==========================================
class DigimonGame extends FlameGame with HasCollisionDetection, HasKeyboardHandlerComponents {
  int stage = 1;
  int lives = 3;
  int ammo = 30;
  int maxAmmo = 99;
  int score = 0;
  bool godMode = false;

  // Inventory & Buffs
  int daging = 0;
  int ramuan = 0;
  int sisik = 0;
  int cakar = 0;
  bool kunci = false;

  bool isInvincible = false;
  bool isDoubleDamage = false;

  late PlayerAgumon player;
  late CameraComponent cameraComp;
  late World gameWorld;

  final VoidCallback onUIUpdate;

  DigimonGame({required this.onUIUpdate});

  @override
  Future<void> onLoad() async {
    gameWorld = World();
    add(gameWorld);

    player = PlayerAgumon();
    gameWorld.add(player);

    cameraComp = CameraComponent(world: gameWorld);
    cameraComp.viewfinder.anchor = Anchor.centerLeft;
    add(cameraComp);

    buildStage(1);
  }

  void buildStage(int stgNo) {
    stage = stgNo;
    gameWorld.children.where((c) => c != player).forEach((c) => c.removeFromParent());

    player.position = Vector2(50, 100);
    player.velocity = Vector2.zero();

    // Map Construction berdasarkan Stage HTML
    if (stage == 1) {
      _buildPlatform(0, 220, 900, 50);
      _buildPlatform(980, 130, 180, 20);
      _buildPlatform(1240, 70, 200, 20);
      _buildPlatform(1500, 220, 1000, 50);

      gameWorld.add(QuestionBlock(position: Vector2(250, 110), type: 'ammo'));
      gameWorld.add(QuestionBlock(position: Vector2(1020, 60), type: 'heart'));

      gameWorld.add(EnemyWalker(position: Vector2(600, 194), minX: 520, maxX: 680));
      gameWorld.add(EnemyWalker(position: Vector2(750, 194), minX: 680, maxX: 820));
      gameWorld.add(EnemyWalker(position: Vector2(1550, 194), minX: 1450, maxX: 1650));

      gameWorld.add(GameItem(type: 'daging', position: Vector2(350, 180)));
      gameWorld.add(GameItem(type: 'ramuan', position: Vector2(700, 180)));
      gameWorld.add(GameItem(type: 'sisik', position: Vector2(1300, 40)));
      gameWorld.add(GameItem(type: 'kunci', position: Vector2(1900, 180)));

      gameWorld.add(FlagPole(position: Vector2(2300, 60)));
    } else if (stage == 2) {
      _buildPlatform(0, 220, 700, 50);
      _buildPlatform(780, 120, 200, 20);
      _buildPlatform(1050, 220, 1200, 50);

      gameWorld.add(EnemyShield(position: Vector2(500, 194), minX: 440, maxX: 560));
      gameWorld.add(EnemyShield(position: Vector2(900, 94), minX: 850, maxX: 950));
      gameWorld.add(EnemyWalker(position: Vector2(1200, 194), minX: 1120, maxX: 1280));

      gameWorld.add(GameItem(type: 'ramuan', position: Vector2(200, 180)));
      gameWorld.add(GameItem(type: 'cakar', position: Vector2(850, 90)));
      gameWorld.add(GameItem(type: 'kunci', position: Vector2(1650, 180)));

      gameWorld.add(FlagPole(position: Vector2(2000, 60)));
    } else if (stage == 3) {
      _buildPlatform(0, 220, 1000, 50);
      gameWorld.add(BossMetalGreymon(position: Vector2(600, 130)));
    }

    onUIUpdate();
  }

  void _buildPlatform(double x, double y, double w, double h) {
    gameWorld.add(PlatformBlock(position: Vector2(x, y), size: Vector2(w, h)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    cameraComp.viewfinder.position = Vector2(max(0, player.position.x - 100), 0);
  }

  void jumpPlayer() => player.jump();

  void shootPlayer() {
    if (godMode || ammo > 0) {
      if (!godMode) ammo--;
      gameWorld.add(Fireball(
        position: Vector2(player.position.x + (player.isFacingRight ? 30 : -10), player.position.y + 10),
        isRight: player.isFacingRight,
      ));
      onUIUpdate();
    }
  }

  void useItem(String item) {
    if (item == 'daging' && daging > 0) {
      daging--; lives = min(5, lives + 1);
    } else if (item == 'ramuan' && ramuan > 0) {
      ramuan--; ammo = min(maxAmmo, ammo + 20);
    } else if (item == 'sisik' && sisik > 0) {
      sisik--; isInvincible = true;
      Future.delayed(const Duration(seconds: 5), () => isInvincible = false);
    } else if (item == 'cakar' && cakar > 0) {
      cakar--; isDoubleDamage = true;
      Future.delayed(const Duration(seconds: 10), () => isDoubleDamage = false);
    }
    onUIUpdate();
  }

  void handleDeath() {
    if (godMode || isInvincible) return;
    lives--;
    onUIUpdate();
    if (lives > 0) {
      player.position = Vector2(50, 100);
      player.velocity = Vector2.zero();
    } else {
      buildStage(1);
      lives = 3;
      ammo = 30;
      score = 0;
      onUIUpdate();
    }
  }
}

// ==========================================
// GAME COMPONENTS & PHYSICS
// ==========================================
class PlayerAgumon extends PositionComponent with HasGameRef<DigimonGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  bool isFacingRight = true;
  final double gravity = 950.0;

  PlayerAgumon() : super(size: Vector2(28, 32)) {
    add(RectangleHitbox());
  }

  void move(double dir) {
    velocity.x = dir * 160;
    if (dir != 0) isFacingRight = dir > 0;
  }

  void jump() {
    if (isGrounded) {
      velocity.y = -400;
      isGrounded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocity.y += gravity * dt;
    if (velocity.y > 600) velocity.y = 600;
    position += velocity * dt;

    if (position.y > 400) gameRef.handleDeath();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlatformBlock) {
      if (velocity.y > 0 && position.y + size.y - velocity.y * 0.016 <= other.position.y + 10) {
        position.y = other.position.y - size.y;
        velocity.y = 0;
        isGrounded = true;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final paintBody = Paint()..color = const Color(0xFFFF9900);
    final paintBelly = Paint()..color = const Color(0xFFFFCC66);
    final paintEye = Paint()..color = Colors.black;

    canvas.drawRect(Rect.fromLTWH(0, 4, size.x, size.y - 4), paintBody);
    canvas.drawRect(Rect.fromLTWH(4, 10, size.x - 8, size.y - 14), paintBelly);
    canvas.drawRect(Rect.fromLTWH(isFacingRight ? size.x - 6 : 2, 2, 4, 6), paintEye);
  }
}

class PlatformBlock extends PositionComponent with CollisionCallbacks {
  PlatformBlock({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF8B4513));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 6), Paint()..color = const Color(0xFF2ECC71));
  }
}

class EnemyWalker extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  double dir = 1;
  final double minX, maxX;
  EnemyWalker({required Vector2 position, required this.minX, required this.maxX})
      : super(position: position, size: Vector2(26, 26)) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += dir * 60 * dt;
    if (position.x > maxX || position.x < minX) dir *= -1;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon) gameRef.handleDeath();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFFCC3300));
  }
}

class EnemyShield extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  double dir = 1;
  final double minX, maxX;
  EnemyShield({required Vector2 position, required this.minX, required this.maxX})
      : super(position: position, size: Vector2(26, 26)) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += dir * 50 * dt;
    if (position.x > maxX || position.x < minX) dir *= -1;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon) gameRef.handleDeath();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF34495E));
  }
}

class BossMetalGreymon extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  int hp = 12;
  double dir = -1;

  BossMetalGreymon({required Vector2 position}) : super(position: position, size: Vector2(60, 54)) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += dir * 80 * dt;
    if (position.x < 400 || position.x > 800) dir *= -1;
  }

  void takeDamage(int dmg) {
    hp -= dmg;
    if (hp <= 0) {
      removeFromParent();
      gameRef.buildStage(1); // Victory, reset stage
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon) gameRef.handleDeath();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF922B21));
    canvas.drawRect(Rect.fromLTWH(0, -10, (hp / 12) * size.x, 5), Paint()..color = Colors.red);
  }
}

class Fireball extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  final bool isRight;
  Fireball({required Vector2 position, required this.isRight})
      : super(position: position, size: Vector2(10, 10)) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (isRight ? 380 : -380) * dt;
    if (position.x > playerXLimit() || position.x < -100) removeFromParent();
  }

  double playerXLimit() => gameRef.player.position.x + 800;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is EnemyWalker) {
      other.removeFromParent();
      removeFromParent();
    } else if (other is EnemyShield) {
      other.removeFromParent();
      removeFromParent();
    } else if (other is BossMetalGreymon) {
      other.takeDamage(gameRef.isDoubleDamage ? 2 : 1);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 5, Paint()..color = Colors.deepOrange);
  }
}

class GameItem extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  final String type;
  GameItem({required this.type, required Vector2 position})
      : super(position: position, size: Vector2(20, 20)) {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon) {
      if (type == 'daging') gameRef.daging++;
      if (type == 'ramuan') gameRef.ramuan++;
      if (type == 'sisik') gameRef.sisik++;
      if (type == 'cakar') gameRef.cakar++;
      if (type == 'kunci') gameRef.kunci = true;
      gameRef.onUIUpdate();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    String icon = '🍖';
    if (type == 'ramuan') icon = '🧪';
    if (type == 'sisik') icon = '🛡️';
    if (type == 'cakar') icon = '🔥';
    if (type == 'kunci') icon = '🔑';

    final textPainter = TextPainter(
      text: TextSpan(text: icon, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset.zero);
  }
}

class QuestionBlock extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  final String type;
  bool isUsed = false;
  QuestionBlock({required Vector2 position, required this.type})
      : super(position: position, size: Vector2(24, 24)) {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon && !isUsed) {
      isUsed = true;
      if (type == 'ammo') gameRef.ammo = min(gameRef.maxAmmo, gameRef.ammo + 10);
      if (type == 'heart') gameRef.lives = min(5, gameRef.lives + 1);
      gameRef.onUIUpdate();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = isUsed ? Colors.grey : Colors.orangeAccent);
  }
}

class FlagPole extends PositionComponent with CollisionCallbacks, HasGameRef<DigimonGame> {
  FlagPole({required Vector2 position}) : super(position: position, size: Vector2(10, 160)) {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerAgumon) {
      gameRef.buildStage(gameRef.stage + 1);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(10, 0, 30, 20), Paint()..color = Colors.red);
  }
}

// ==========================================
// FLUTTER DASHBOARD & HUD UI
// ==========================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DigimonGame game;

  @override
  void initState() {
    super.initState();
    game = DigimonGame(onUIUpdate: () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Upper Canvas Viewport (55%)
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                GameWidget(game: game),
                Positioned(
                  top: 10, left: 10, right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("STG: 1-${game.stage}", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                      Row(
                        children: [
                          Text("❤️" * game.lives, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 10),
                          Text("🔫 ${game.godMode ? '∞' : game.ammo}", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                        ],
                      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Inventory
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _invButton("🍖", game.daging, () => game.useItem('daging')),
                        _invButton("🧪", game.ramuan, () => game.useItem('ramuan')),
                        _invButton("🛡️", game.sisik, () => game.useItem('sisik')),
                        _invButton("🔥", game.cakar, () => game.useItem('cakar')),
                        Text("🔑 ${game.kunci ? '✅' : '❌'}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),

                  // Touch Controls
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
                              child: _dirButton(Icons.arrow_left, (isPressed) {
                                game.player.move(isPressed ? -1 : 0);
                              }),
                            ),
                            Positioned(
                              right: 0, top: 33,
                              child: _dirButton(Icons.arrow_right, (isPressed) {
                                game.player.move(isPressed ? 1 : 0);
                              }),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Row(
                        children: [
                          _actionBtn("B", "FIRE", Colors.redAccent, game.shootPlayer),
                          const SizedBox(width: 15),
                          _actionBtn("A", "JUMP", const Color(0xFF900C3F), game.jumpPlayer),
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

  Widget _invButton(String icon, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(4)),
        child: Text("$icon $count", style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }

  Widget _dirButton(IconData icon, Function(bool) onPressed) {
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
      mainAxisSize: min,
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
