import 'package:flutter/material.dart';

/// Shared backdrop for the menu/select screens: the jungle artwork, a dark
/// scrim over it for text contrast, then [body] on top. [appBar] (if any)
/// stays transparent so the art shows through behind it too.
class MenuBackgroundScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  const MenuBackgroundScaffold({super.key, this.appBar, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/menu_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          body,
        ],
      ),
    );
  }
}
