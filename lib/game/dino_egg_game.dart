import 'dart:collection';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../models/difficulty.dart';
import '../models/game_state.dart';
import 'effects/pop_effect.dart';
import 'entities/aim_line.dart';
import 'entities/egg_bubble.dart';
import 'entities/launcher.dart';
import 'entities/next_bubble_indicator.dart';
import 'grid/hex_grid.dart';
import 'logic/floating_detector.dart';
import 'logic/match_finder.dart';

/// Board dimensions, matching the reference screenshots' proportions
/// (roughly 7-8 bubbles wide).
const int kGridRows = 10;
const int kGridCols = 8;

/// Aim direction is clamped away from dead-horizontal so the player can
/// never fire sideways or into the launcher itself.
const double _minAngleFromHorizontal = 0.15;

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
  DinoEggGame({this.difficulty = Difficulty.normal});

  final Difficulty difficulty;

  late HexGrid grid;
  late Launcher launcher;
  late Vector2 launcherPosition;
  late double _bubbleDiameter;
  late int _rowCount;

  double aimAngle = -pi / 2;
  EggColor? currentColor;
  EggColor? nextColor;

  GameStatus status = GameStatus.playing;

  /// A [ValueNotifier] (rather than a plain int) so the score can be shown
  /// live in a Flutter widget outside the Flame canvas (the bottom HUD)
  /// without polling every frame.
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int get score => scoreNotifier.value;

  int shotsFired = 0;

  final Map<(int, int), EggBubble> _bubbleAt = {};
  EggBubble? _projectile;
  Vector2? _projectileVelocity;

  final _random = Random();

  List<EggColor> get _palette => EggColor.values.take(difficulty.colorCount).toList();

  @override
  Color backgroundColor() => const Color(0xFF16351F);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await loadEggSprites(images);

    _bubbleDiameter = size.x / kGridCols;

    launcherPosition = Vector2(size.x / 2, size.y - _bubbleDiameter);
    launcher = Launcher(diameter: _bubbleDiameter, position: launcherPosition.clone());
    add(launcher);
    add(NextBubbleIndicator());
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
  /// again whenever the player restarts from the game-over/win overlay.
  void _startNewRound() {
    for (final bubble in _bubbleAt.values) {
      bubble.removeFromParent();
    }
    _bubbleAt.clear();
    _projectile?.removeFromParent();
    _projectile = null;
    _projectileVelocity = null;

    grid = HexGrid(
      rows: _rowCount,
      cols: kGridCols,
      bubbleDiameter: _bubbleDiameter,
    );
    // Always leave a few empty rows above the launcher at the start —
    // filling too close to _rowCount left almost no room before the
    // bottom-row loss check, making the very first shots feel unfair.
    final initialFillRows = (_rowCount - 4).clamp(3, 6);
    _fillTestRows(rowCount: initialFillRows);
    _renderGridBubbles();

    status = GameStatus.playing;
    scoreNotifier.value = 0;
    shotsFired = 0;
    currentColor = _randomAvailableColor();
    nextColor = _randomAvailableColor();
  }

  /// Called by the game-over/win overlay's "play again" action.
  void restart() {
    _startNewRound();
    overlays.remove('gameOver');
    overlays.remove('youWin');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _advanceProjectile(dt);
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

  // --- Firing & projectile flight ---------------------------------------

  void _fire() {
    if (status != GameStatus.playing) return;
    if (_projectile != null || currentColor == null) return;

    final diameter = grid.bubbleDiameter;
    final direction = Vector2(cos(aimAngle), sin(aimAngle));

    final bubble = EggBubble(
      color: currentColor!,
      diameter: diameter,
      position: launcherPosition.clone(),
    );
    _projectile = bubble;
    _projectileVelocity = direction * diameter * 7;
    add(bubble);

    shotsFired++;
    currentColor = nextColor;
    nextColor = _randomAvailableColor();
  }

  void _advanceProjectile(double dt) {
    final bubble = _projectile;
    final velocity = _projectileVelocity;
    if (bubble == null || velocity == null) return;

    final from = bubble.position.clone();
    var to = from + velocity * dt;

    // Sweep the whole segment travelled this frame against every existing
    // bubble using their true touching distance (one full diameter, since
    // both circles have the same radius) — this is what actually stops the
    // ball from being able to slip past the outer shell of a cluster.
    final hit = _sweepCollision(from, to);
    if (hit != null) {
      _settleProjectile(bubble, hit);
      return;
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
      _settleAtTop(bubble, to);
    }
  }

  /// The first existing bubble whose true collision circle (one full
  /// diameter — the distance at which two equal circles touch) the segment
  /// [from]->[to] enters this frame, via ray-circle intersection.
  _Collision? _sweepCollision(Vector2 from, Vector2 to) {
    final touchDistance = grid.bubbleDiameter;
    final d = to - from;
    final a = d.dot(d);

    _Collision? earliest;
    for (final entry in _bubbleAt.entries) {
      final centerOffset = grid.cellCenter(entry.key.$1, entry.key.$2);
      final center = Vector2(centerOffset.dx, centerOffset.dy);
      final f = from - center;
      final c = f.dot(f) - touchDistance * touchDistance;

      double? t;
      if (a <= 1e-9) {
        if (c <= 0) t = 0;
      } else {
        final b = 2 * f.dot(d);
        final discriminant = b * b - 4 * a * c;
        if (discriminant >= 0) {
          final sqrtDisc = sqrt(discriminant);
          final t1 = (-b - sqrtDisc) / (2 * a);
          if (t1 >= 0 && t1 <= 1) {
            t = t1;
          } else if (c <= 0) {
            t = 0; // already overlapping at the start of this frame.
          }
        }
      }

      if (t == null) continue;
      if (earliest == null || t < earliest.t) {
        earliest = _Collision(entry.key, center, from + d * t, t);
      }
    }
    return earliest;
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
        final neighborCenterOffset = grid.cellCenter(neighbor.$1, neighbor.$2);
        final dir = Vector2(
          neighborCenterOffset.dx - hit.hitCenter.x,
          neighborCenterOffset.dy - hit.hitCenter.y,
        ).normalized();
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
    _projectile = null;
    _projectileVelocity = null;
    bubble.removeFromParent();

    final (row, col) = landing;
    grid.place(row, col, bubble.color);
    _bubbleAt[(row, col)] = _spawnGridBubble(row, col, bubble.color);

    _resolveMatchesAndFalls(row, col);
    if (_checkWinLose()) return;

    if (shotsFired % difficulty.shotsPerPushDown == 0) {
      _pushRowDown();
      _removeFloatingCells();
      _checkWinLose();
    }
  }

  // --- Matching & falling -------------------------------------------------

  void _resolveMatchesAndFalls(int row, int col) {
    final matched = findMatch(grid, row, col);
    for (final (r, c) in matched) {
      grid.clear(r, c);
      _popBubbleAt((r, c));
    }

    // Always re-check for orphaned bubbles, even when this placement didn't
    // pop anything itself — skipping this check whenever matched was empty
    // let disconnected bubbles from an earlier state linger unnoticed.
    final fallen = _removeFloatingCells();

    if (matched.isNotEmpty || fallen > 0) {
      scoreNotifier.value += (matched.length + fallen) * 10;
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
  /// burst in its color at its last position.
  void _popBubbleAt((int, int) coord) {
    final bubble = _bubbleAt.remove(coord);
    if (bubble == null) return;
    add(PopEffect(position: bubble.position.clone(), color: bubble.color));
    bubble.removeFromParent();
  }

  /// Shifts every row down by one and fills a fresh row at the top. Any
  /// bubbles that were already in the bottom row are pushed past the
  /// boundary — that's a loss, checked by the caller via [_checkWinLose].
  void _pushRowDown() {
    for (var r = grid.rows - 1; r >= 1; r--) {
      grid.setRowColors(r, grid.rowColors(r - 1));
    }
    final colors = _palette;
    grid.setRowColors(
      0,
      List.generate(grid.cols, (_) => colors[_random.nextInt(colors.length)]),
    );

    for (final bubble in _bubbleAt.values) {
      bubble.removeFromParent();
    }
    _bubbleAt.clear();
    _renderGridBubbles();
  }

  /// Returns true if the round ended (won or lost) as a result of the
  /// latest board mutation.
  bool _checkWinLose() {
    if (grid.occupiedCells.isEmpty) {
      status = GameStatus.won;
      overlays.add('youWin');
      return true;
    }
    if (_pileReachesLauncher() || _bottomRowOccupied()) {
      status = GameStatus.lost;
      overlays.add('gameOver');
      return true;
    }
    return false;
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
      _bubbleAt[(cell.row, cell.col)] = _spawnGridBubble(cell.row, cell.col, cell.color!);
    }
  }

  EggBubble _spawnGridBubble(int row, int col, EggColor color) {
    final center = grid.cellCenter(row, col);
    final bubble = EggBubble(
      color: color,
      diameter: grid.bubbleDiameter,
      position: Vector2(center.dx, center.dy),
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
    final points = <Vector2>[launcherPosition.clone()];
    var origin = launcherPosition.clone();
    var direction = Vector2(cos(aimAngle), sin(aimAngle));

    for (var bounce = 0; bounce < 4; bounce++) {
      final tTop = direction.y != 0 ? (0 - origin.y) / direction.y : double.infinity;
      double tWall = double.infinity;
      if (direction.x > 0) {
        tWall = (size.x - origin.x) / direction.x;
      } else if (direction.x < 0) {
        tWall = (0 - origin.x) / direction.x;
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
