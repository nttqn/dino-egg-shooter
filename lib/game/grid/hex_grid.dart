import 'dart:math';
import 'dart:ui';

/// Colors an egg bubble can have. Kept as an enum so match/floating logic
/// can compare cheaply and rendering can map to a palette.
enum EggColor { red, blue, green, yellow, purple }

/// A single slot in the hex grid. `color` is null when the slot is empty.
class GridCell {
  final int row;
  final int col;
  EggColor? color;

  GridCell({required this.row, required this.col, this.color});

  bool get isEmpty => color == null;
}

/// Offset-coordinate hex grid used for the bubble board.
///
/// Rows are packed tightly (row height = diameter * sqrt(3)/2) and odd rows
/// are shifted right by half a bubble diameter, matching the classic
/// Puzzle Bobble / Bust-a-Move board layout shown in the reference screenshots.
class HexGrid {
  final int rows;
  final int cols;
  final double bubbleDiameter;
  final double offsetX;
  final double offsetY;

  late final List<List<GridCell>> _cells;
  late final double rowHeight;

  HexGrid({
    required this.rows,
    required this.cols,
    required this.bubbleDiameter,
    this.offsetX = 0,
    this.offsetY = 0,
  }) {
    rowHeight = bubbleDiameter * (sqrt(3) / 2);
    _cells = List.generate(
      rows,
      (r) => List.generate(cols, (c) => GridCell(row: r, col: c)),
    );
  }

  GridCell cellAt(int row, int col) => _cells[row][col];

  bool inBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  /// True for a row shifted right by half a bubble (odd rows).
  bool _isShiftedRow(int row) => row.isOdd;

  /// Pixel center of a grid cell, relative to the grid's own origin.
  Offset cellCenter(int row, int col) {
    final radius = bubbleDiameter / 2;
    final shift = _isShiftedRow(row) ? radius : 0.0;
    final x = offsetX + shift + radius + col * bubbleDiameter;
    final y = offsetY + radius + row * rowHeight;
    return Offset(x, y);
  }

  /// The grid cell whose center is closest to [point], clamped to always be
  /// a valid in-bounds cell (even if [point] lies outside the grid's own
  /// pixel bounds, e.g. below the last row).
  (int, int) nearestCell(Offset point) {
    final approxRow = ((point.dy - offsetY) / rowHeight).round().clamp(0, rows - 1);
    final loRow = (approxRow - 1).clamp(0, rows - 1);
    final hiRow = (approxRow + 1).clamp(0, rows - 1);

    (int, int)? best;
    var bestDist = double.infinity;
    for (var r = loRow; r <= hiRow; r++) {
      for (var c = 0; c < cols; c++) {
        final dist = (cellCenter(r, c) - point).distanceSquared;
        if (dist < bestDist) {
          bestDist = dist;
          best = (r, c);
        }
      }
    }
    return best!;
  }

  /// The six neighbor coordinates of a cell, in-bounds only.
  List<(int, int)> neighborsOf(int row, int col) {
    final shifted = _isShiftedRow(row);
    final deltas = shifted
        ? const [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)]
        : const [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)];

    final result = <(int, int)>[];
    for (final (dr, dc) in deltas) {
      final nr = row + dr;
      final nc = col + dc;
      if (inBounds(nr, nc)) result.add((nr, nc));
    }
    return result;
  }

  void place(int row, int col, EggColor color) {
    _cells[row][col].color = color;
  }

  void clear(int row, int col) {
    _cells[row][col].color = null;
  }

  /// All occupied cells, e.g. for rendering or iteration.
  Iterable<GridCell> get occupiedCells =>
      _cells.expand((row) => row).where((cell) => !cell.isEmpty);

  List<EggColor?> rowColors(int row) =>
      _cells[row].map((cell) => cell.color).toList();

  void setRowColors(int row, List<EggColor?> colors) {
    for (var c = 0; c < cols; c++) {
      _cells[row][c].color = colors[c];
    }
  }
}
