import '../grid/hex_grid.dart';

/// After a pop, some clusters may no longer be connected (directly or
/// transitively) to the top row and should fall off the board.
///
/// Returns every occupied cell that is NOT reachable from row 0.
List<(int, int)> findFloatingCells(HexGrid grid) {
  final anchored = <(int, int)>{};
  final stack = <(int, int)>[];

  for (var col = 0; col < grid.cols; col++) {
    if (!grid.cellAt(0, col).isEmpty) {
      anchored.add((0, col));
      stack.add((0, col));
    }
  }

  while (stack.isNotEmpty) {
    final (r, c) = stack.removeLast();
    for (final (nr, nc) in grid.neighborsOf(r, c)) {
      if (anchored.contains((nr, nc))) continue;
      if (grid.cellAt(nr, nc).isEmpty) continue;
      anchored.add((nr, nc));
      stack.add((nr, nc));
    }
  }

  return grid.occupiedCells
      .map((cell) => (cell.row, cell.col))
      .where((coord) => !anchored.contains(coord))
      .toList();
}
