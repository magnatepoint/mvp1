import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/goals_models.dart';
import '../../../widgets/glass_card.dart';
import '../../../theme/premium_theme.dart';
import '../../../animations/card_animations.dart';

class GoalSelectionStep extends StatefulWidget {
  final List<GoalCatalogItem> catalog;
  final List<GoalCatalogItem> recommended;
  final Function(List<GoalCatalogItem>) onSelect;
  final VoidCallback onBack;

  const GoalSelectionStep({
    super.key,
    required this.catalog,
    required this.recommended,
    required this.onSelect,
    required this.onBack,
  });

  @override
  State<GoalSelectionStep> createState() => _GoalSelectionStepState();
}

class _GoalSelectionStepState extends State<GoalSelectionStep> {
  final Set<String> _selected = {};
  String _filter = 'all';

  void _toggleGoal(GoalCatalogItem goal) {
    setState(() {
      if (_selected.contains(goal.key)) {
        _selected.remove(goal.key);
      } else {
        _selected.add(goal.key);
      }
    });
  }

  void _selectRecommended() {
    setState(() {
      _selected.clear();
      for (var goal in widget.recommended) {
        _selected.add(goal.key);
      }
    });
  }

  void _handleSubmit() {
    final selectedGoals = widget.catalog
        .where((g) => _selected.contains(g.key))
        .toList();
    
    if (selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one goal')),
      );
      return;
    }
    
    widget.onSelect(selectedGoals);
  }

  List<GoalCatalogItem> get _filteredGoals {
    if (_filter == 'all') {
      return widget.catalog;
    }
    return widget.catalog.where((g) => g.defaultHorizon == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Your Financial Goals',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose one or more goals that matter to you.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Recommended banner
          if (widget.recommended.isNotEmpty)
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderColor: Colors.amber.withOpacity(0.5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Based on your profile, we recommend:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _selectRecommended,
                          style: TextButton.styleFrom(
                            foregroundColor: PremiumTheme.goldPrimary,
                          ),
                          child: const Text('Select Recommended Goals'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeInSlideUp(),
          const SizedBox(height: 16),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterTab('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterTab('short_term', 'Short Term (0-2y)'),
                const SizedBox(width: 8),
                _buildFilterTab('medium_term', 'Medium Term (2-5y)'),
                const SizedBox(width: 8),
                _buildFilterTab('long_term', 'Long Term (5y+)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Goals grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _filteredGoals.length,
            itemBuilder: (context, index) {
              final goal = _filteredGoals[index];
              final isSelected = _selected.contains(goal.key);
              final isRecommended = widget.recommended.any(
                (r) => r.goalCategory == goal.goalCategory && r.goalName == goal.goalName,
              );
              
              return InkWell(
                onTap: () => _toggleGoal(goal),
                borderRadius: BorderRadius.circular(20),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: isSelected
                      ? PremiumTheme.goldPrimary.withOpacity(0.8)
                      : null,
                  borderWidth: isSelected ? 2 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleGoal(goal),
                            activeColor: PremiumTheme.goldPrimary,
                          ),
                          if (isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          if (goal.isMandatoryFlag)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Essential',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          goal.goalName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        goal.goalCategory,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      if (goal.suggestedMinAmountFormula != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${goal.suggestedMinAmountFormula}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 50).ms),
              );
            },
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.goldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: Text('Continue (${_selected.length} selected)'),
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

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: PremiumTheme.goldPrimary.withOpacity(0.2),
      checkmarkColor: PremiumTheme.goldPrimary,
      labelStyle: TextStyle(
        color: isSelected ? PremiumTheme.goldPrimary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? PremiumTheme.goldPrimary.withOpacity(0.5)
            : Colors.grey.withOpacity(0.3),
        width: isSelected ? 1.5 : 1,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = value;
          });
        }
      },
    )
        .animate()
        .scale(delay: 50.ms, begin: const Offset(0.9, 0.9));
  }
}

