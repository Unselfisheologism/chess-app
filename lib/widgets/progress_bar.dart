import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// Progress bar shown at the top of the lesson player. Renders as a
/// row of pips — filled (gold) for completed questions, current
/// (deep ink with gold border) for the active one, empty (cream)
/// for upcoming.
class LessonProgressBar extends StatelessWidget {
  final int currentIndex;
  final int total;

  const LessonProgressBar({
    super.key,
    required this.currentIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        Color color;
        if (i < currentIndex) {
          color = BrandColors.gold;
        } else if (i == currentIndex) {
          color = BrandColors.deepInk;
        } else {
          color = BrandColors.cream;
        }
        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
