import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/goals_models.dart';

class GoalDetailStep extends StatefulWidget {
  final SelectedGoal goal;
  final GoalCatalogItem? catalogItem;
  final int currentIndex;
  final int totalGoals;
  final Function(SelectedGoal) onSubmit;
  final VoidCallback onBack;

  const GoalDetailStep({
    super.key,
    required this.goal,
    this.catalogItem,
    required this.currentIndex,
    required this.totalGoals,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<GoalDetailStep> createState() => _GoalDetailStepState();
}

class _GoalDetailStepState extends State<GoalDetailStep> {
  late SelectedGoal _formData;
  final Map<String, String> _errors = {};
  final TextEditingController _estimatedCostController = TextEditingController();
  final TextEditingController _currentSavingsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _formData = widget.goal;
    _estimatedCostController.text = _formData.estimatedCost.toString();
    _currentSavingsController.text = _formData.currentSavings.toString();
    _notesController.text = _formData.notes ?? '';
    if (_formData.targetDate != null) {
      _targetDate = _formData.targetDate;
    } else {
      _targetDate = _getDefaultTargetDate();
    }
  }

  @override
  void dispose() {
    _estimatedCostController.dispose();
    _currentSavingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _getDefaultTargetDate() {
    final today = DateTime.now();
    if (widget.catalogItem?.defaultHorizon == 'short_term') {
      return DateTime(today.year + 1, today.month, today.day);
    } else if (widget.catalogItem?.defaultHorizon == 'medium_term') {
      return DateTime(today.year + 3, today.month, today.day);
    } else if (widget.catalogItem?.defaultHorizon == 'long_term') {
      return DateTime(today.year + 7, today.month, today.day);
    } else {
      return DateTime(today.year + 3, today.month, today.day);
    }
  }

  bool _validate() {
    _errors.clear();
    bool isValid = true;

    final estimatedCost = double.tryParse(_estimatedCostController.text);
    if (estimatedCost == null || estimatedCost <= 0) {
      _errors['estimated_cost'] = 'Estimated cost must be greater than 0';
      isValid = false;
    }

    if (_formData.importance < 1 || _formData.importance > 5) {
      _errors['importance'] = 'Importance must be between 1 and 5';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  void _handleSubmit() {
    if (_validate()) {
      final estimatedCost = double.tryParse(_estimatedCostController.text) ?? 0.0;
      final currentSavings = double.tryParse(_currentSavingsController.text) ?? 0.0;
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final updatedGoal = _formData.copyWith(
        estimatedCost: estimatedCost,
        currentSavings: currentSavings,
        targetDate: _targetDate,
        notes: notes,
      );

      widget.onSubmit(updatedGoal);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? _getDefaultTargetDate(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.goal.goalName} (${widget.currentIndex + 1} of ${widget.totalGoals})',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.goal.goalCategory,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Estimated Cost
          TextFormField(
            controller: _estimatedCostController,
            decoration: InputDecoration(
              labelText: 'Estimated Cost (₹) *',
              hintText: widget.catalogItem?.suggestedMinAmountFormula != null
                  ? widget.catalogItem!.suggestedMinAmountFormula
                  : null,
              errorText: _errors['estimated_cost'],
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Target Date
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Target Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _targetDate != null
                    ? DateFormat('yyyy-MM-dd').format(_targetDate!)
                    : 'Select date',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Leave empty to use default based on goal horizon',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          // Current Savings
          TextFormField(
            controller: _currentSavingsController,
            decoration: const InputDecoration(
              labelText: 'Current Savings (₹)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.savings),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Importance
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Importance (1-5) * - ${_formData.importance}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _formData.importance.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: _formData.importance.toString(),
                onChanged: (value) {
                  setState(() {
                    _formData = _formData.copyWith(importance: value.toInt());
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Low'),
                  Text('High'),
                ],
              ),
              if (_errors['importance'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _errors['importance']!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional notes about this goal...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.onBack,
                child: Text(widget.currentIndex > 0 ? 'Previous' : 'Back'),
              ),
              ElevatedButton(
                onPressed: _handleSubmit,
                child: Text(
                  widget.currentIndex < widget.totalGoals - 1
                      ? 'Next Goal'
                      : 'Review',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

