import 'package:flutter/material.dart';

import '../theme/brand.dart';

enum FeedbackKind { correct, wrong }

/// Full-screen feedback overlay. Briefly shows a colored pulse (green
/// for correct, red for wrong) plus the [explanation] text. Tapping
/// or waiting dismisses it.
class FeedbackOverlay extends StatelessWidget {
  final FeedbackKind kind;
  final String explanation;
  final VoidCallback onDismiss;

  const FeedbackOverlay({
    super.key,
    required this.kind,
    required this.explanation,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = kind == FeedbackKind.correct;
    final color = isCorrect ? BrandColors.success : BrandColors.error;
    final icon = isCorrect ? Icons.check_circle : Icons.cancel;
    final label = isCorrect ? 'Correct!' : 'Not quite';

    return Material(
      color: color.withOpacity(0.95),
      child: InkWell(
        onTap: onDismiss,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 96),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  explanation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Tap to continue',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
