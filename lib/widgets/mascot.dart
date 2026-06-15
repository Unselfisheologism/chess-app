import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/brand.dart';

/// The chess-do-it mascot. A round pawn-shaped character with two
/// black eyes, animated via Lottie.
///
/// The 3 animations are hand-authored Lottie JSON (not from a
/// text-to-Lottie tool — that doesn't exist; if you want a fancier
/// version, swap the JSON files in assets/lottie/ for assets from
/// lottiefiles.com).
enum MascotMood { idle, celebrate, sad }

class Mascot extends StatelessWidget {
  final MascotMood mood;
  final double size;

  const Mascot({
    super.key,
    this.mood = MascotMood.idle,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      _pathFor(mood),
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Celebrate plays once and stops on the final frame; idle and
      // sad loop. (Loop keeps idle from looking frozen; sad loops
      // so the droop is visible on slower devices.)
      repeat: mood != MascotMood.celebrate,
      // Brand background so the Lottie's transparent background
      // doesn't blend into whatever's behind it.
      options: LottieOptions(backgroundColor: BrandColors.cream),
      errorBuilder: (context, error, stackTrace) {
        // Fallback if the Lottie file fails to parse — show a
        // simple text avatar so the UI still works.
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BrandColors.cream,
            shape: BoxShape.circle,
          ),
          child: Text(
            mood == MascotMood.sad ? '😕' : '♟',
            style: const TextStyle(fontSize: 48),
          ),
        );
      },
    );
  }

  String _pathFor(MascotMood mood) {
    switch (mood) {
      case MascotMood.idle:
        return 'assets/lottie/pawn_idle.json';
      case MascotMood.celebrate:
        return 'assets/lottie/pawn_celebrate.json';
      case MascotMood.sad:
        return 'assets/lottie/pawn_sad.json';
    }
  }
}
