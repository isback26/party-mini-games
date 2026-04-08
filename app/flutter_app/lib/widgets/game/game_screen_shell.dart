import 'package:flutter/material.dart';

class GameScreenShell extends StatelessWidget {
  final Widget top;
  final Widget center;
  final Widget bottom;
  final int centerFlex;
  final int bottomFlex;
  final double gapTopToCenter;
  final double gapCenterToBottom;

  const GameScreenShell({
    super.key,
    required this.top,
    required this.center,
    required this.bottom,
    this.centerFlex = 0,
    this.bottomFlex = 1,
    this.gapTopToCenter = 8,
    this.gapCenterToBottom = 10,
  });

  Widget _buildSection({required Widget child, required int flex}) {
    if (flex <= 0) {
      return child;
    }
    return Expanded(flex: flex, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        top,
        SizedBox(height: gapTopToCenter),
        _buildSection(child: center, flex: centerFlex),
        SizedBox(height: gapCenterToBottom),
        _buildSection(child: bottom, flex: bottomFlex),
      ],
    );
  }
}
