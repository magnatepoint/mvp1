import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../models/goals_models.dart';
import '../../../widgets/glass_card.dart';
import '../../../theme/premium_theme.dart';
import '../../../animations/card_animations.dart';

class ReviewStep extends StatelessWidget {
  final LifeContext? lifeContext;
  final List<SelectedGoal> selectedGoals;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final bool submitting;

  const ReviewStep({
    super.key,
    this.lifeContext,
    required this.selectedGoals,
    required this.onSubmit,
    required this.onBack,
    this.submitting = false,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return DateFormat('dd MMMM yyyy', 'en_IN').format(date);
  }

  double _getProgress(SelectedGoal goal) {
    if (goal.estimatedCost == 0) return 0;
    return (goal.currentSavings / goal.estimatedCost * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Goals',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Life Context
          if (lifeContext != null)
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Life Context',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildReviewRow('Age Range:', lifeContext!.ageBand),
                  const SizedBox(height: 8),
                  _buildReviewRow(
                    'Housing:',
                    lifeContext!.housing.replaceAll('_', ' '),
                  ),
                  const SizedBox(height: 8),
                  _buildReviewRow(
                    'Employment:',
                    lifeContext!.employment.replaceAll('_', ' '),
                  ),
                  const SizedBox(height: 8),
                  _buildReviewRow(
                    'Income Stability:',
                    lifeContext!.incomeRegularity.replaceAll('_', ' '),
                  ),
                  const SizedBox(height: 8),
                  _buildReviewRow('Region:', lifeContext!.regionCode),
                ],
              ),
            )
                .animate()
                .fadeInSlideUp(),
          const SizedBox(height: 16),
          // Selected Goals
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Goals (${selectedGoals.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ...selectedGoals.asMap().entries.map((entry) {
                  final index = entry.key;
                  final goal = entry.value;
                  return _buildGoalReviewItem(context, goal, index);
                }),
              ],
            ),
          )
              .animate()
              .fadeInSlideUp(delay: 200.ms),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.goldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Submit Goals'),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(delay: 100.ms, begin: const Offset(0.9, 0.9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalReviewItem(
    BuildContext context,
    SelectedGoal goal,
    int index,
  ) {
    final progress = _getProgress(goal);
    final remaining = goal.estimatedCost - goal.currentSavings;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.goalName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: PremiumTheme.goldPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PremiumTheme.goldPrimary.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  goal.goalCategory,
                  style: TextStyle(
                    fontSize: 12,
                    color: PremiumTheme.goldPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewRow('Target Amount:', _formatCurrency(goal.estimatedCost)),
          const SizedBox(height: 8),
          _buildReviewRow(
            'Current Savings:',
            _formatCurrency(goal.currentSavings),
          ),
          const SizedBox(height: 8),
          _buildReviewRow('Remaining:', _formatCurrency(remaining)),
          const SizedBox(height: 8),
          _buildReviewRow('Target Date:', _formatDate(goal.targetDate)),
          const SizedBox(height: 8),
          _buildReviewRow('Importance:', '${goal.importance}/5'),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 100 ? Colors.green : PremiumTheme.goldPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          if (goal.notes != null && goal.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              goal.notes!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeInSlideUp(delay: (index * 100).ms);
  }
}

