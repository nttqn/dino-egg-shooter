import 'package:flutter_test/flutter_test.dart';

import 'package:dino_egg_shooter/main.dart';

void main() {
  testWidgets('App boots and shows the game widget', (tester) async {
    await tester.pumpWidget(const DinoEggShooterApp());
    await tester.pump();

    expect(find.byType(DinoEggShooterApp), findsOneWidget);
  });
}
