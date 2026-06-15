import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';

/// Multiple-choice shell. Shows the prompt, then 4 option buttons
/// in a vertical column. Tapping an option submits the answer; the
/// parent (LessonPlayerScreen) handles validation + feedback.
class MultipleChoiceShell extends StatelessWidget {
  final LessonQuestion question;
  final bool isLocked;
  final void Function(int selectedIndex) onSubmit;

  const MultipleChoiceShell({
    super.key,
    required this.question,
    required this.isLocked,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final options = question.options ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.prompt,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        ...List.generate(options.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: _OptionButton(
              label: options[i],
              onTap: isLocked ? null : () => onSubmit(i),
            ),
          );
        }),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _OptionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Colors.white : BrandColors.cream,
      borderRadius: BorderRadius.circular(AppSpacing.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            border: Border.all(color: BrandColors.deepInk, width: 2),
            borderRadius: BorderRadius.circular(AppSpacing.m),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(Icons.chevron_right, color: BrandColors.deepInk),
            ],
          ),
        ),
      ),
    );
  }
}
