import 'package:dino_egg_shooter/game/grid/hex_grid.dart';
import 'package:dino_egg_shooter/game/logic/match_finder.dart';
import 'package:flutter_test/flutter_test.dart';

HexGrid _grid() => HexGrid(rows: 4, cols: 3, bubbleDiameter: 10);

void main() {
  test('shiftRowsDown moves rows and their special flags down', () {
    final grid = _grid();
    grid.place(0, 1, EggColor.red, special: true);

    grid.shiftRowsDown([EggColor.blue, EggColor.blue, EggColor.blue], specialCol: 2);

    expect(grid.cellAt(1, 1).color, EggColor.red);
    expect(grid.cellAt(1, 1).special, isTrue);
    expect(grid.cellAt(0, 2).special, isTrue);
    expect(grid.cellAt(0, 0).special, isFalse);
    expect(grid.specialCount, 2);
  });

  test('shiftRowsUp discards row 0 and empties the last row', () {
    final grid = _grid();
    grid.place(0, 0, EggColor.red);
    grid.place(1, 0, EggColor.green, special: true);
    grid.place(3, 2, EggColor.blue);

    grid.shiftRowsUp();

    expect(grid.cellAt(0, 0).color, EggColor.green);
    expect(grid.cellAt(0, 0).special, isTrue);
    expect(grid.cellAt(2, 2).color, EggColor.blue);
    expect(grid.cellAt(3, 2).isEmpty, isTrue);
  });

  test('clear resets the special flag', () {
    final grid = _grid();
    grid.place(2, 1, EggColor.yellow, special: true);
    grid.clear(2, 1);
    expect(grid.cellAt(2, 1).special, isFalse);
  });

  test('connectedSameColor returns clusters smaller than a match', () {
    final grid = _grid();
    grid.place(0, 0, EggColor.red);
    grid.place(0, 1, EggColor.red);

    expect(connectedSameColor(grid, 0, 0).length, 2);
    expect(findMatch(grid, 0, 0), isEmpty);

    grid.place(0, 2, EggColor.red);
    expect(findMatch(grid, 0, 0).length, 3);
  });
}
