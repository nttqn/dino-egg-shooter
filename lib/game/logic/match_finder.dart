import '../grid/hex_grid.dart';

/// Minimum cluster size for a match to pop.
const int kMinMatchSize = 3;

/// Flood-fills from (row, col) across same-colored, connected cells.
/// Returns the matching cluster, or an empty list if it's below
/// [kMinMatchSize] (i.e. nothing should pop).
List<(int, int)> findMatch(HexGrid grid, int row, int col) {
  final origin = grid.cellAt(row, col);
  final color = origin.color;
  if (color == null) return const [];

  final visited = <(int, int)>{(row, col)};
  final stack = [(row, col)];
  final cluster = <(int, int)>[(row, col)];

  while (stack.isNotEmpty) {
    final (r, c) = stack.removeLast();
    for (final (nr, nc) in grid.neighborsOf(r, c)) {
      if (visited.contains((nr, nc))) continue;
      visited.add((nr, nc));
      final neighborCell = grid.cellAt(nr, nc);
      if (neighborCell.color == color) {
        cluster.add((nr, nc));
        stack.add((nr, nc));
      }
    }
  }

  return cluster.length >= kMinMatchSize ? cluster : const [];
}
