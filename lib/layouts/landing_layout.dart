import 'package:flutter/material.dart';

/// Layout wrapper for the landing page (before project is loaded)
class LandingLayout extends StatelessWidget {
  const LandingLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: baseFontSize * 4.57,
              horizontal: baseFontSize * 2.29,
            ),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
