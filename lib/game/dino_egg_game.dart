import 'dart:collection';
import 'dart:math';

import 'package:flame/components.dart' show TimerComponent;
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../models/difficulty.dart';
import '../models/dino_species.dart';
import '../models/game_mode.dart';
import '../models/game_state.dart';
import '../services/dino_collection.dart';
import '../services/sound_service.dart';
import 'effects/hatch_banner.dart';
import 'effects/pop_effect.dart';
import 'entities/aim_line.dart';
import 'entities/announcement_text.dart';
import 'entities/background_layer.dart';
import 'entities/companion_dino.dart';
import 'entities/dino_npc.dart';
import 'entities/dino_portraits.dart';
import 'entities/egg_bubble.dart';
import 'entities/launcher.dart';
import 'entities/loaded_egg_indicator.dart';
import 'grid/hex_grid.dart';
import 'logic/floating_detector.dart';
import 'logic/match_finder.dart';

/// Board dimensions, matching the reference screenshots' proportions
/// (roughly 7-8 bubbles wide). kGridRows is a cap, not a target — on a tall
/// portrait phone there's room for well more than the old cap of 10, which
/// left a huge empty gap between the pile and the launcher.
const int kGridRows = 18;
const int kGridCols = 8;

/// Aim direction is clamped away from dead-horizontal so the player can
/// never fire sideways or into the launcher itself.
const double _minAngleFromHorizontal = 0.15;

/// Companion skill charge (0..1) gained per egg popped by a normal shot.
const double kEnergyPerMatched = 0.07;
const double kEnergyPerFallen = 0.04;
const double kEnergyPerHatch = 0.25;

/// Chance that a pushed-down row carries a glowing (hatchable) egg, and the
/// most of them allowed on the board at once.
const double kSpecialEggChancePerRow = 0.12;
const int kMaxSpecialEggs = 2;

/// How long a hatch banner occupies the screen, used to queue several.
const double _hatchBannerSlot = 2.5;

/// Result of a swept collision check: the cell that was hit, that cell's
/// pixel center, the exact contact point along the ball's path, and how
/// far into that frame's movement (in [0, 1]) the hit occurred.
class _Collision {
  final (int, int) cell;
  final Vector2 hitCenter;
  final Vector2 point;
  final double t;
  _Collision(this.cell, this.hitCenter, this.point, this.t);
}

class DinoEggGame extends FlameGame
    with TapCallbacks, DragCallbacks, PointerMoveCallbacks {
  DinoEggGame({
    this.difficulty = Difficulty.normal,
    this.mode = GameMode.endless,
    this.companion = DinoCollection.starter,
  });

  final Difficulty difficulty;
  final GameMode mode;
  final DinoSpecies companion;

  late HexGrid grid;
  late Launcher launcher;
  late DinoNpc dinoNpc;
  late CompanionDino companionDino;
  late BackgroundLayer background;
  late Vector2 launcherPosition;
  late double _bubbleDiameter;
  late int _rowCount;

  double aimAngle = -pi / 2;
  EggColor? currentColor;
  EggColor? nextColor;

  /// True while the dino NPC's tossed egg is mid-flight to the launcher —
  /// used by [DinoNpc]/[LoadedEggIndicator] to avoid drawing two eggs at
  /// once during that animation.
  bool isTossing = false;

  GameStatus status = GameStatus.playing;

  /// A [ValueNotifier] (rather than a plain int) so the score can be shown
  /// live in a Flutter widget outside the Flame canvas (the bottom HUD)
  /// without polling every frame.
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int get score => scoreNotifier.value;

  /// Normal-mode level. Each time the board clears, this advances and the
  /// push-down pacing gets faster; unused by the other modes.
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  int get level => levelNotifier.value;

  /// Time Trial's countdown, in whole seconds; unused by the other modes.
  final ValueNotifier<int> timeRemainingNotifier = ValueNotifier<int>(kTimeTrialSeconds);
  double _timeAccumulator = 0;

  /// Companion skill charge, 0..1; the skill is usable at 1.
  final ValueNotifier<double> energyNotifier = ValueNotifier<double>(0);

  /// A skill waiting to be applied to the next shot, if any.
  final ValueNotifier<ShotModifier?> armedNotifier = ValueNotifier<ShotModifier?>(null);
  ShotModifier? get armedModifier => armedNotifier.value;

  int shotsFired = 0;

  final Map<(int, int), EggBubble> _bubbleAt = {};
  EggBubble? _projectile;
  Vector2? _projectileVelocity;
  ShotModifier? _projectileModifier;
  int _piercedCount = 0;

  double _elapsed = 0;
  double _nextHatchBannerAt = 0;

  final _random = Random();

  List<EggColor> get _palette => EggColor.values.take(difficulty.colorCount).toList();

  /// Normal mode ramps up by pushing rows down more often each level;
  /// Endless and Time Trial stay at the difficulty's flat pacing.
  int get _effectiveShotsPerPushDown {
    if (mode != GameMode.normal) return difficulty.shotsPerPushDown;
    return max(2, difficulty.shotsPerPushDown - (level - 1));
  }

  @override
  Color backgroundColor() => const Color(0xFF16351F);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await loadEggSprites(images);
    await loadDinoAnimations(images);
    await loadBackgrounds(images);
    await loadDinoPortraits(images);

    background = BackgroundLayer();
    add(background);

    _bubbleDiameter = size.x / kGridCols;

    launcherPosition = Vector2(size.x / 2, size.y - _bubbleDiameter);
    launcher = Launcher(diameter: _bubbleDiameter, position: launcherPosition.clone());
    add(launcher);

    dinoNpc = DinoNpc(
      position: Vector2(
        launcherPosition.x - _bubbleDiameter * 1.9,
        launcherPosition.y - _bubbleDiameter * 0.1,
      ),
      eggDiameter: _bubbleDiameter,
    );
    add(dinoNpc);

    companionDino = CompanionDino(
      species: companion,
      position: Vector2(launcherPosition.x + _bubbleDiameter * 2.1, size.y - _bubbleDiameter * 0.15),
      height: _bubbleDiameter * 2.2,
    );
    add(companionDino);

    add(LoadedEggIndicator());
    add(AimLine());

    // Cap the grid to however many rows actually fit above the launcher —
    // on a short/wide viewport, kGridRows worth of pixel height can otherwise
    // overflow past the launcher before the "bottom row" ever fills, which
    // silently blocks play instead of triggering a loss.
    final rowHeight = _bubbleDiameter * (sqrt(3) / 2);
    final playableHeight = launcherPosition.y - _bubbleDiameter * 2;
    final rowsThatFit = (playableHeight / rowHeight).floor() + 1;
    _rowCount = rowsThatFit.clamp(6, kGridRows);

    _startNewRound();
  }

  /// Resets the board to a fresh, playable state. Called on first load and
  /// again whenever the player restarts from a round-end overlay.
  void _startNewRound() {
    _projectile?.removeFromParent();
    _projectile = null;
    _projectileVelocity = null;
    _projectileModifier = null;
    _piercedCount = 0;

    _populateBoard();

    status = GameStatus.playing;
    scoreNotifier.value = 0;
    shotsFired = 0;
    isTossing = false;
    levelNotifier.value = 1;
    timeRemainingNotifier.value = kTimeTrialSeconds;
    _timeAccumulator = 0;
    energyNotifier.value = 0;
    armedNotifier.value = null;
    currentColor = _randomAvailableColor();
    nextColor = _randomAvailableColor();

    add(AnnouncementText(mode == GameMode.normal ? 'LEVEL 1' : 'START'));
  }

  /// Builds a fresh grid and fills it — shared by [_startNewRound] and
  /// [_boardCleared], which differ only in what round state they reset
  /// around it.
  void _populateBoard() {
    background.randomize();

    for (final bubble in _bubbleAt.values) {
      bubble.removeFromParent();
    }
    _bubbleAt.clear();

    grid = HexGrid(
      rows: _rowCount,
      cols: kGridCols,
      bubbleDiameter: _bubbleDiameter,
    );
    // Scale with _rowCount (not a flat cap) so a tall portrait screen — which
    // can fit far more rows than a squarish test window — still starts with
    // a reasonably full board instead of a mostly-empty one, while always
    // keeping a few empty rows of buffer above the launcher.
    final initialFillRows = (_rowCount * 0.6).round().clamp(3, _rowCount - 3);
    _fillTestRows(rowCount: initialFillRows);
    _placeStartingSpecialEgg(filledRows: initialFillRows);
    _renderGridBubbles();
  }

  /// Every fresh board gets one glowing egg, in the lower half of the
  /// filled rows so it's reachable early rather than buried at the top.
  void _placeStartingSpecialEgg({required int filledRows}) {
    final lower = grid.occupiedCells.where((cell) => cell.row >= filledRows ~/ 2).toList();
    if (lower.isEmpty) return;
    lower[_random.nextInt(lower.length)].special = true;
  }

  /// Called by a round-end overlay's "play again" action.
  void restart() {
    _startNewRound();
    overlays.remove('gameOver');
    overlays.remove('timeUp');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _advanceProjectile(dt);
    if (mode == GameMode.timeTrial && status == GameStatus.playing) {
      _updateCountdown(dt);
    }
  }

  void _updateCountdown(double dt) {
    _timeAccumulator += dt;
    while (_timeAccumulator >= 1.0 && timeRemainingNotifier.value > 0) {
      _timeAccumulator -= 1.0;
      timeRemainingNotifier.value--;
    }
    if (timeRemainingNotifier.value <= 0) {
      _triggerTimeUp();
    }
  }

  void _triggerTimeUp() {
    status = GameStatus.timeUp;
    _projectile?.removeFromParent();
    _projectile = null;
    _projectileVelocity = null;
    _projectileModifier = null;
    overlays.add('timeUp');
  }

  // --- Input -----------------------------------------------------------

  @override
  void onPointerMove(PointerMoveEvent event) => _updateAim(event.canvasPosition);

  @override
  void onDragUpdate(DragUpdateEvent event) => _updateAim(event.canvasEndPosition);

  @override
  void onTapUp(TapUpEvent event) => _fire();

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _fire();
  }

  void _updateAim(Vector2 pointerPos) {
    if (status != GameStatus.playing) return;

    final dx = pointerPos.x - launcherPosition.x;
    var dy = pointerPos.y - launcherPosition.y;
    if (dy > -1) dy = -1; // always aim upward, even if the pointer is below the launcher.

    var angle = atan2(dy, dx);
    const minAngle = -pi + _minAngleFromHorizontal;
    const maxAngle = -_minAngleFromHorizontal;
    angle = angle.clamp(minAngle, maxAngle);

    aimAngle = angle;
    launcher.barrelAngle = angle;
  }

  // --- Companion skill ---------------------------------------------------

  bool get abilityReady => energyNotifier.value >= 1 && armedNotifier.value == null;

  /// Spends a full charge on [companion]'s skill: board-wide skills act
  /// immediately, shot skills arm the next egg fired.
  void activateAbility() {
    if (status != GameStatus.playing || paused) return;
    if (!abilityReady || _projectile != null) return;

    energyNotifier.value = 0;
    companionDino.celebrate();
    final ability = companion.info.ability;
    add(AnnouncementText(ability.title.toUpperCase(), fontSize: 30));

    switch (ability) {
      case DinoAbility.stomp:
        _stomp();
      case DinoAbility.lift:
        _eatTopRow();
      case DinoAbility.pierce:
        armedNotifier.value = ShotModifier.pierce;
      case DinoAbility.bomb:
        armedNotifier.value = ShotModifier.bomb;
      case DinoAbility.rainbow:
        armedNotifier.value = ShotModifier.rainbow;
    }
  }

  void _addEnergy(double amount) {
    energyNotifier.value = min(1.0, energyNotifier.value + amount);
  }

  /// Clears the two lowest occupied rows.
  void _stomp() {
    final occupied = grid.occupiedCells.toList();
    if (occupied.isEmpty) return;
    final lowest = occupied.map((cell) => cell.row).reduce(max);
    _popCells([
      for (final cell in occupied)
        if (cell.row >= lowest - 1) (cell.row, cell.col),
    ]);
    _checkWinLose();
  }

  /// Removes row 0 and moves the whole pile up one row.
  void _eatTopRow() {
    final eaten = [
      for (var c = 0; c < grid.cols; c++)
        if (!grid.cellAt(0, c).isEmpty) (0, c),
    ];
    for (final coord in eaten) {
      grid.clear(coord.$1, coord.$2);
      _popBubbleAt(coord);
    }
    grid.shiftRowsUp();
    _rerenderAllBubbles();

    final fallen = _removeFloatingCells();
    _awardPops(eaten.length + fallen);
    _checkWinLose();
  }

  /// Pops [cells] regardless of color, then drops anything left floating.
  /// Doesn't check win/lose — callers decide when that runs.
  void _popCells(List<(int, int)> cells) {
    for (final (r, c) in cells) {
      grid.clear(r, c);
      _popBubbleAt((r, c));
    }
    final fallen = _removeFloatingCells();
    _awardPops(cells.length + fallen);
  }

  void _awardPops(int count) {
    if (count <= 0) return;
    scoreNotifier.value += count * 10;
    SoundService.playPop();
  }

  // --- Firing & projectile flight ---------------------------------------

  void _fire() {
    if (status != GameStatus.playing) return;
    // isTossing also gates firing, not just the projectile itself — without
    // it, a fast shot landing before the dino's ~0.28s toss animation
    // finishes lets the player fire again mid-throw, restarting/interrupting
    // it and making the animation look glitchy.
    if (_projectile != null || isTossing || currentColor == null) return;

    final diameter = grid.bubbleDiameter;
    final direction = Vector2(cos(aimAngle), sin(aimAngle));

    final modifier = armedNotifier.value;
    armedNotifier.value = null;

    final bubble = EggBubble(
      color: currentColor!,
      diameter: diameter,
      position: launcherPosition.clone(),
      modifier: modifier,
    );
    _projectile = bubble;
    _projectileVelocity = direction * diameter * 11;
    _projectileModifier = modifier;
    _piercedCount = 0;
    add(bubble);
    SoundService.playShoot();

    shotsFired++;
    final incoming = nextColor;
    currentColor = nextColor;
    nextColor = _randomAvailableColor();
    if (incoming != null) _tossNextEggToLauncher(incoming);
  }

  /// Animates the dino NPC's held egg flying from its hands into the
  /// launcher, taking over the "loaded egg" spot visually until it lands.
  void _tossNextEggToLauncher(EggColor color) {
    isTossing = true;
    dinoNpc.playThrow();
    final egg = EggBubble(
      color: color,
      diameter: grid.bubbleDiameter,
      position: dinoNpc.handPosition.clone(),
    );
    add(egg);
    egg.add(
      MoveToEffect(
        launcherPosition.clone(),
        EffectController(duration: dinoThrowDuration, curve: Curves.easeOut),
        onComplete: () {
          egg.removeFromParent();
          isTossing = false;
        },
      ),
    );
  }

  void _advanceProjectile(double dt) {
    final bubble = _projectile;
    final velocity = _projectileVelocity;
    if (bubble == null || velocity == null) return;

    final from = bubble.position.clone();
    var to = from + velocity * dt;

    final piercing = _projectileModifier == ShotModifier.pierce;
    if (piercing) {
      for (final coord in _sweepAll(from, to)) {
        grid.clear(coord.$1, coord.$2);
        _popBubbleAt(coord);
        _piercedCount++;
      }
    } else {
      // Sweep the whole segment travelled this frame against every existing
      // bubble using their true touching distance (one full diameter, since
      // both circles have the same radius) — this is what actually stops the
      // ball from being able to slip past the outer shell of a cluster.
      final hit = _sweepCollision(from, to);
      if (hit != null) {
        _settleProjectile(bubble, hit);
        return;
      }
    }

    final radius = bubble.radius;
    if (to.x - radius <= 0) {
      to = Vector2(radius, to.y);
      velocity.x = -velocity.x;
    } else if (to.x + radius >= size.x) {
      to = Vector2(size.x - radius, to.y);
      velocity.x = -velocity.x;
    }
    bubble.position = to;

    if (to.y - radius <= 0) {
      if (piercing) {
        _finishPierce(bubble);
      } else {
        _settleAtTop(bubble, to);
      }
    }
  }

  /// Using the true full-diameter touch distance is mathematically correct
  /// but means an exactly-one-cell gap between two neighbors is *always*
  /// too narrow to thread (closest approach through it is ≈0.866×diameter)
  /// — every such gap becomes unshootable, which reads as "collision is too
  /// generous" rather than as intentional physics. Shrinking the effective
  /// radius trades a bit of realism for gaps that are visually one cell
  /// wide actually being shootable.
  double get _touchDistance => grid.bubbleDiameter * 0.82;

  /// How far along the segment `from + d*t` (t in [0, 1]) it first comes
  /// within [_touchDistance] of [center], via ray-circle intersection; null
  /// if it never does this frame.
  double? _hitTime(Vector2 from, Vector2 d, double a, Vector2 center) {
    final touchDistance = _touchDistance;
    final f = from - center;
    final c = f.dot(f) - touchDistance * touchDistance;
    if (a <= 1e-9) return c <= 0 ? 0 : null;

    final b = 2 * f.dot(d);
    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return null;
    final t1 = (-b - sqrt(discriminant)) / (2 * a);
    if (t1 >= 0 && t1 <= 1) return t1;
    if (c <= 0) return 0; // already overlapping at the start of this frame.
    return null;
  }

  Vector2 _centerOf((int, int) cell) {
    final offset = grid.cellCenter(cell.$1, cell.$2);
    return Vector2(offset.dx, offset.dy);
  }

  /// The first existing bubble the segment [from]->[to] touches this frame.
  _Collision? _sweepCollision(Vector2 from, Vector2 to) {
    final d = to - from;
    final a = d.dot(d);

    _Collision? earliest;
    for (final cell in _bubbleAt.keys) {
      final center = _centerOf(cell);
      final t = _hitTime(from, d, a, center);
      if (t == null) continue;
      if (earliest == null || t < earliest.t) {
        earliest = _Collision(cell, center, from + d * t, t);
      }
    }
    return earliest;
  }

  /// Every existing bubble the segment [from]->[to] touches this frame.
  List<(int, int)> _sweepAll(Vector2 from, Vector2 to) {
    final d = to - from;
    final a = d.dot(d);
    return [
      for (final cell in _bubbleAt.keys)
        if (_hitTime(from, d, a, _centerOf(cell)) != null) cell,
    ];
  }

  /// A piercing egg doesn't stick anywhere: once it reaches the top, score
  /// everything it tore through plus whatever that left floating.
  void _finishPierce(EggBubble bubble) {
    _projectile = null;
    _projectileVelocity = null;
    _projectileModifier = null;
    bubble.removeFromParent();

    final fallen = _removeFloatingCells();
    _awardPops(_piercedCount + fallen);
    _piercedCount = 0;
    _afterShotResolved();
  }

  void _settleAtTop(EggBubble bubble, Vector2 position) {
    final nearest = grid.nearestCell(Offset(position.x, position.y));
    final landing = grid.cellAt(nearest.$1, nearest.$2).isEmpty
        ? nearest
        : (_nearestEmptyViaBfs(nearest) ?? nearest);
    _place(bubble, landing);
  }

  void _settleProjectile(EggBubble bubble, _Collision hit) {
    _place(bubble, _landingSlotFor(hit));
  }

  /// Picks the empty neighbor of the hit cell whose direction (from the hit
  /// cell's own center) best matches the collision normal — i.e. the slot
  /// the ball actually pressed into, not just "whichever empty cell happens
  /// to be closest to some point," which can pick a slot behind the wall
  /// the ball bounced off of.
  (int, int) _landingSlotFor(_Collision hit) {
    final normal = hit.point - hit.hitCenter;
    if (normal.length2 >= 1e-9) {
      final normalDir = normal.normalized();
      (int, int)? best;
      var bestScore = -double.infinity;
      for (final neighbor in grid.neighborsOf(hit.cell.$1, hit.cell.$2)) {
        if (!grid.cellAt(neighbor.$1, neighbor.$2).isEmpty) continue;
        final dir = (_centerOf(neighbor) - hit.hitCenter).normalized();
        final score = dir.dot(normalDir);
        if (score > bestScore) {
          bestScore = score;
          best = neighbor;
        }
      }
      if (best != null) return best;
    }

    // No empty neighbor exists (the hit cell is fully boxed in) — search
    // outward through the occupied mass for the nearest empty cell. Never
    // fall back to hit.cell itself: that would silently overwrite an
    // existing bubble instead of placing a new one.
    return _nearestEmptyViaBfs(hit.cell) ?? hit.cell;
  }

  /// Breadth-first search outward from [start] through occupied cells for
  /// the nearest empty one. Guarantees a real, unoccupied landing slot as
  /// long as the board isn't completely full.
  (int, int)? _nearestEmptyViaBfs((int, int) start) {
    final visited = <(int, int)>{start};
    final queue = Queue<(int, int)>()..add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in grid.neighborsOf(current.$1, current.$2)) {
        if (!visited.add(neighbor)) continue;
        if (grid.cellAt(neighbor.$1, neighbor.$2).isEmpty) return neighbor;
        queue.add(neighbor);
      }
    }
    return null;
  }

  void _place(EggBubble bubble, (int, int) landing) {
    final modifier = _projectileModifier;
    _projectile = null;
    _projectileVelocity = null;
    _projectileModifier = null;
    bubble.removeFromParent();

    final (row, col) = landing;
    final color = modifier == ShotModifier.rainbow
        ? _bestRainbowColor(landing, bubble.color)
        : bubble.color;
    grid.place(row, col, color);
    _bubbleAt[(row, col)] = _spawnGridBubble(row, col, color);
    SoundService.playStick();

    if (modifier == ShotModifier.bomb) {
      _popCells(_cellsWithinRings(landing, 2));
    } else {
      // Skill-boosted shots don't recharge the skill, so it can't chain.
      _resolveMatchesAndFalls(row, col, chargesEnergy: modifier == null);
    }
    _afterShotResolved();
  }

  void _afterShotResolved() {
    if (_checkWinLose()) return;

    if (shotsFired % _effectiveShotsPerPushDown == 0) {
      _pushRowDown();
      _removeFloatingCells();
      _checkWinLose();
    }
  }

  /// Of the colors touching [landing], the one that would join the largest
  /// same-color cluster there.
  EggColor _bestRainbowColor((int, int) landing, EggColor fallback) {
    final (row, col) = landing;
    final candidates = {
      for (final (r, c) in grid.neighborsOf(row, col)) grid.cellAt(r, c).color,
    }.whereType<EggColor>();

    var best = fallback;
    var bestSize = 0;
    for (final color in candidates) {
      grid.place(row, col, color);
      final size = connectedSameColor(grid, row, col).length;
      grid.clear(row, col);
      if (size > bestSize) {
        bestSize = size;
        best = color;
      }
    }
    return best;
  }

  /// Occupied cells within [rings] steps of [center], including itself.
  List<(int, int)> _cellsWithinRings((int, int) center, int rings) {
    final reached = <(int, int)>{center};
    var frontier = [center];
    for (var i = 0; i < rings; i++) {
      final next = <(int, int)>[];
      for (final (r, c) in frontier) {
        for (final neighbor in grid.neighborsOf(r, c)) {
          if (reached.add(neighbor)) next.add(neighbor);
        }
      }
      frontier = next;
    }
    return reached.where((cell) => !grid.cellAt(cell.$1, cell.$2).isEmpty).toList();
  }

  // --- Matching & falling -------------------------------------------------

  void _resolveMatchesAndFalls(int row, int col, {bool chargesEnergy = true}) {
    final matched = findMatch(grid, row, col);
    for (final (r, c) in matched) {
      grid.clear(r, c);
      _popBubbleAt((r, c));
    }

    // Always re-check for orphaned bubbles, even when this placement didn't
    // pop anything itself — skipping this check whenever matched was empty
    // let disconnected bubbles from an earlier state linger unnoticed.
    final fallen = _removeFloatingCells();

    _awardPops(matched.length + fallen);
    if (chargesEnergy) {
      _addEnergy(matched.length * kEnergyPerMatched + fallen * kEnergyPerFallen);
    }
  }

  /// Removes every bubble no longer connected (directly or transitively) to
  /// the top row. Returns how many were removed.
  int _removeFloatingCells() {
    final floating = findFloatingCells(grid);
    for (final (r, c) in floating) {
      grid.clear(r, c);
      _popBubbleAt((r, c));
    }
    return floating.length;
  }

  /// Removes the bubble component at [coord] and fires a small particle
  /// burst in its color at its last position. A glowing egg hatches.
  void _popBubbleAt((int, int) coord) {
    final bubble = _bubbleAt.remove(coord);
    if (bubble == null) return;
    add(PopEffect(position: bubble.position.clone(), color: bubble.color, diameter: grid.bubbleDiameter));
    bubble.removeFromParent();
    if (bubble.special) _hatchAt(bubble.position.clone());
  }

  /// Hatches a dinosaur from a popped glowing egg, adding it to the
  /// collection (saved immediately, so a later loss doesn't undo it).
  void _hatchAt(Vector2 position) {
    final species = DinoCollection.pickHatchling(_random);
    final isNew = DinoCollection.recordHatch(species);

    final delay = max(0.0, _nextHatchBannerAt - _elapsed);
    _nextHatchBannerAt = _elapsed + delay + _hatchBannerSlot;
    add(HatchSparkle(position: position));
    add(HatchBanner(species: species, isNew: isNew, startDelay: delay));

    scoreNotifier.value += isNew ? 100 : 50;
    _addEnergy(kEnergyPerHatch);
    SoundService.playMenuConfirm();
  }

  /// Shifts every row down by one and fills a fresh row at the top. Any
  /// bubbles that were already in the bottom row are pushed past the
  /// boundary — that's a loss, checked by the caller via [_checkWinLose].
  void _pushRowDown() {
    final colors = _palette;
    final specialCol =
        grid.specialCount < kMaxSpecialEggs && _random.nextDouble() < kSpecialEggChancePerRow
            ? _random.nextInt(grid.cols)
            : null;
    grid.shiftRowsDown(
      List.generate(grid.cols, (_) => colors[_random.nextInt(colors.length)]),
      specialCol: specialCol,
    );
    _rerenderAllBubbles();
  }

  void _rerenderAllBubbles() {
    for (final bubble in _bubbleAt.values) {
      bubble.removeFromParent();
    }
    _bubbleAt.clear();
    _renderGridBubbles();
  }

  /// Returns true if the round ended (lost, or Time Trial's clock ran out)
  /// as a result of the latest board mutation. Clearing the board never
  /// ends the round — see [_boardCleared].
  bool _checkWinLose() {
    if (status != GameStatus.playing) return status == GameStatus.lost;
    if (grid.occupiedCells.isEmpty) {
      _boardCleared();
      return false;
    }
    if (_pileReachesLauncher() || _bottomRowOccupied()) {
      _triggerLossCollapse();
      return true;
    }
    return false;
  }

  /// The board emptied out. In Normal mode that's completing a level —
  /// advance it (which ramps up push-down pacing) before refilling; the
  /// other modes just refill at the same pacing and keep going.
  void _boardCleared() {
    if (mode == GameMode.normal) {
      levelNotifier.value++;
    }
    _populateBoard();
    currentColor = _randomAvailableColor();
    nextColor = _randomAvailableColor();

    if (mode == GameMode.normal) {
      add(AnnouncementText('LEVEL $level'));
    }
  }

  /// Loss sequence: block input immediately, then send every remaining
  /// bubble crashing down off the bottom of the screen (staggered from the
  /// bottom row up, like the pile toppling over) with a pop burst at each
  /// one, and only show the game-over overlay once that's finished.
  void _triggerLossCollapse() {
    status = GameStatus.lost;
    _projectile?.removeFromParent();
    _projectile = null;
    _projectileVelocity = null;
    _projectileModifier = null;
    armedNotifier.value = null;

    final bubbles = _bubbleAt.values.toList();
    _bubbleAt.clear();

    var maxDelay = 0.0;
    for (final bubble in bubbles) {
      add(PopEffect(position: bubble.position.clone(), color: bubble.color, diameter: grid.bubbleDiameter));

      final row = grid.nearestCell(Offset(bubble.position.x, bubble.position.y)).$1;
      final delay = (grid.rows - 1 - row) * 0.025;
      maxDelay = max(maxDelay, delay);

      final fallDistance = size.y - bubble.position.y + grid.bubbleDiameter;
      final sway = (_random.nextDouble() - 0.5) * grid.bubbleDiameter * 2;
      bubble.add(
        MoveByEffect(
          Vector2(sway, fallDistance),
          EffectController(duration: 0.6, startDelay: delay, curve: Curves.easeIn),
          onComplete: () => bubble.removeFromParent(),
        ),
      );
    }

    add(
      TimerComponent(
        period: maxDelay + 0.7,
        removeOnFinish: true,
        onTick: () => overlays.add('gameOver'),
      ),
    );
  }

  /// The grid has no row below the last one, so a ball hitting a bottom-row
  /// bubble from underneath has nowhere correct to attach — it would get
  /// redirected up into the row above, which looks like it passed through.
  /// Ending the round as soon as the last row has anything in it keeps that
  /// situation from ever being reachable.
  bool _bottomRowOccupied() {
    final lastRow = grid.rows - 1;
    for (var c = 0; c < grid.cols; c++) {
      if (!grid.cellAt(lastRow, c).isEmpty) return true;
    }
    return false;
  }

  /// Checked by pixel distance to the launcher rather than a fixed row
  /// index, so it stays correct regardless of the viewport's aspect ratio.
  bool _pileReachesLauncher() {
    final dangerY = launcherPosition.y - _bubbleDiameter * 0.75;
    for (final cell in grid.occupiedCells) {
      if (grid.cellCenter(cell.row, cell.col).dy >= dangerY) return true;
    }
    return false;
  }

  // --- Board population helpers ------------------------------------------

  void _fillTestRows({required int rowCount}) {
    final colors = _palette;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < kGridCols; c++) {
        grid.place(r, c, colors[_random.nextInt(colors.length)]);
      }
    }
  }

  void _renderGridBubbles() {
    for (final cell in grid.occupiedCells) {
      _bubbleAt[(cell.row, cell.col)] =
          _spawnGridBubble(cell.row, cell.col, cell.color!, special: cell.special);
    }
  }

  EggBubble _spawnGridBubble(int row, int col, EggColor color, {bool special = false}) {
    final center = grid.cellCenter(row, col);
    final bubble = EggBubble(
      color: color,
      diameter: grid.bubbleDiameter,
      position: Vector2(center.dx, center.dy),
      special: special,
    );
    add(bubble);
    return bubble;
  }

  EggColor? _randomAvailableColor() {
    final available = _bubbleAt.values.map((b) => b.color).toSet();
    if (available.isEmpty) {
      final colors = _palette;
      return colors[_random.nextInt(colors.length)];
    }
    final list = available.toList();
    return list[_random.nextInt(list.length)];
  }

  /// Computes the aim-line polyline: launcher -> ... -> first wall bounce(s)
  /// -> top of the board. Used by [AimLine] for the trajectory preview.
  List<Vector2> computeAimPath() {
    // Wall bounces must reflect off the projectile's edge, not its center —
    // matching _advanceProjectile's `to.x - radius <= 0` / `+radius >=
    // size.x` — otherwise this preview bounces a full radius later/deeper
    // than where the real egg actually bounces.
    final radius = _bubbleDiameter / 2;
    final points = <Vector2>[launcherPosition.clone()];
    var origin = launcherPosition.clone();
    var direction = Vector2(cos(aimAngle), sin(aimAngle));

    for (var bounce = 0; bounce < 4; bounce++) {
      final tTop = direction.y != 0 ? (0 - origin.y) / direction.y : double.infinity;
      double tWall = double.infinity;
      if (direction.x > 0) {
        tWall = (size.x - radius - origin.x) / direction.x;
      } else if (direction.x < 0) {
        tWall = (radius - origin.x) / direction.x;
      }

      final t = min(tTop, tWall);
      if (!t.isFinite) break;

      final next = origin + direction * t;
      points.add(next);
      if (t == tTop) break;

      direction = Vector2(-direction.x, direction.y);
      origin = next;
    }

    return points;
  }
}
