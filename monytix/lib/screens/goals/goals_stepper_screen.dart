import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../services/goals_service.dart';
import '../../models/goals_models.dart';
import '../../widgets/glass_card.dart';
import '../../theme/premium_theme.dart';
import '../../animations/card_animations.dart';
import 'steps/life_context_step.dart';
import 'steps/goal_selection_step.dart';
import 'steps/goal_detail_step.dart';
import 'steps/review_step.dart';

class GoalsStepperScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const GoalsStepperScreen({
    super.key,
    this.onComplete,
  });

  @override
  State<GoalsStepperScreen> createState() => _GoalsStepperScreenState();
}

class _GoalsStepperScreenState extends State<GoalsStepperScreen> {
  final GoalsService _goalsService = GoalsService(ApiService());
  
  int _currentStep = 1;
  LifeContext? _lifeContext;
  List<GoalCatalogItem> _goalCatalog = [];
  List<GoalCatalogItem> _recommendedGoals = [];
  List<SelectedGoal> _selectedGoals = [];
  int _currentGoalIndex = 0;
  bool _loading = false;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load goal catalog
      final catalogData = await _goalsService.getGoalCatalog();
      final catalog = catalogData
          .map((item) => GoalCatalogItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Load existing life context (404 is expected if no context exists)
      LifeContext? existingContext;
      try {
        final contextData = await _goalsService.getLifeContext();
        if (contextData != null) {
          existingContext = LifeContext.fromJson(contextData);
        }
      } catch (e) {
        // 404 is expected for new users
        debugPrint('No existing life context found (expected for new users)');
      }

      // Load recommended goals
      List<GoalCatalogItem> recommended = [];
      try {
        final recommendedData = await _goalsService.getRecommendedGoals();
        recommended = recommendedData
            .map((item) => GoalCatalogItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading recommended goals: $e');
      }

      // If context exists, check if user has existing goals
      if (existingContext != null) {
        try {
          final existingGoals = await _goalsService.getGoals();
          if (existingGoals.isNotEmpty) {
            // User has existing goals, skip to goal selection
            _currentStep = 2;
          }
        } catch (e) {
          debugPrint('Error checking existing goals: $e');
        }
      }

      setState(() {
        _goalCatalog = catalog;
        _recommendedGoals = recommended;
        _lifeContext = existingContext;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _handleLifeContextSubmit(LifeContext context) {
    setState(() {
      _lifeContext = context;
      _currentStep = 2;
    });
  }

  void _handleGoalSelection(List<GoalCatalogItem> goals) {
    // Initialize selected goals with default values
    final initialized = goals.map((goal) {
      return SelectedGoal(
        goalCategory: goal.goalCategory,
        goalName: goal.goalName,
        estimatedCost: 0,
        currentSavings: 0,
        importance: 3,
      );
    }).toList();

    setState(() {
      _selectedGoals = initialized;
      _currentGoalIndex = 0;
      _currentStep = 3;
    });
  }

  void _handleGoalDetailSubmit(SelectedGoal goalDetail) {
    final updated = List<SelectedGoal>.from(_selectedGoals);
    updated[_currentGoalIndex] = goalDetail;

    if (_currentGoalIndex < _selectedGoals.length - 1) {
      setState(() {
        _selectedGoals = updated;
        _currentGoalIndex = _currentGoalIndex + 1;
      });
    } else {
      setState(() {
        _selectedGoals = updated;
        _currentStep = 4;
      });
    }
  }

  void _handleBack() {
    if (_currentStep == 3 && _currentGoalIndex > 0) {
      setState(() {
        _currentGoalIndex = _currentGoalIndex - 1;
      });
    } else if (_currentStep > 1) {
      setState(() {
        _currentStep = _currentStep - 1;
      });
    }
  }

  Future<void> _handleSubmit() async {
    // If no life context and we're on step 1, require it
    if (_lifeContext == null && _currentStep == 1) {
      setState(() {
        _error = 'Life context is required';
      });
      return;
    }

    // If no goals selected, require at least one
    if (_selectedGoals.isEmpty) {
      setState(() {
        _error = 'Please select at least one goal';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _goalsService.submitGoals(
        context: _lifeContext?.toJson(),
        selectedGoals: _selectedGoals.map((g) => g.toJson()).toList(),
      );

      // Success - notify parent and close
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goals submitted successfully!')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _submitting = false;
      });
    }
  }

  GoalCatalogItem? _getCatalogItemForGoal(SelectedGoal goal) {
    try {
      return _goalCatalog.firstWhere(
        (item) =>
            item.goalCategory == goal.goalCategory &&
            item.goalName == goal.goalName,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Set Up Goals'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF121212),
                    const Color(0xFF1E1E1E),
                    const Color(0xFF121212),
                  ]
                : [
                    const Color(0xFFF5F5F5),
                    Colors.white,
                    const Color(0xFFF5F5F5),
                  ],
          ),
        ),
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.goldPrimary),
                ),
              )
            : _error != null && _currentStep == 1
                ? Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $_error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PremiumTheme.goldPrimary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeInSlideUp(),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 80), // Space for app bar
                      // Stepper indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _buildStepIndicator(1, 'Life Context', _currentStep >= 1, _currentStep == 1)
                                .animate()
                                .fadeIn(duration: 300.ms),
                            _buildStepConnector(_currentStep > 1)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 100.ms),
                            _buildStepIndicator(2, 'Select Goals', _currentStep >= 2, _currentStep == 2)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 200.ms),
                            _buildStepConnector(_currentStep > 2)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 300.ms),
                            _buildStepIndicator(3, 'Goal Details', _currentStep >= 3, _currentStep == 3)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 400.ms),
                            _buildStepConnector(_currentStep > 3)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 500.ms),
                            _buildStepIndicator(4, 'Review', _currentStep >= 4, _currentStep == 4)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 600.ms),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Step content
                      Expanded(
                        child: _buildStepContent()
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                      ),
                      // Error message
                      if (_error != null && _currentStep != 1)
                        GlassCard(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          borderColor: Colors.red.withOpacity(0.5),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeInSlideUp(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive, bool isCurrent) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive
                  ? LinearGradient(
                      colors: isCurrent
                          ? PremiumTheme.goldGradient
                          : [
                              PremiumTheme.goldPrimary.withOpacity(0.7),
                              PremiumTheme.goldPrimary,
                            ],
                    )
                  : null,
              color: isActive ? null : Colors.grey[300],
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: PremiumTheme.goldPrimary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive
                  ? PremiumTheme.goldPrimary
                  : Colors.grey[600],
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 20,
      height: 3,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  PremiumTheme.goldPrimary,
                  PremiumTheme.goldPrimary.withOpacity(0.5),
                ],
              )
            : null,
        color: isActive ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return LifeContextStep(
          initialData: _lifeContext,
          onSubmit: _handleLifeContextSubmit,
          onSkip: _lifeContext != null ? () => setState(() => _currentStep = 2) : null,
        );
      case 2:
        return GoalSelectionStep(
          catalog: _goalCatalog,
          recommended: _recommendedGoals,
          onSelect: _handleGoalSelection,
          onBack: _handleBack,
        );
      case 3:
        if (_selectedGoals.isEmpty) {
          return const Center(child: Text('No goals selected'));
        }
        return GoalDetailStep(
          goal: _selectedGoals[_currentGoalIndex],
          catalogItem: _getCatalogItemForGoal(_selectedGoals[_currentGoalIndex]),
          currentIndex: _currentGoalIndex,
          totalGoals: _selectedGoals.length,
          onSubmit: _handleGoalDetailSubmit,
          onBack: _handleBack,
        );
      case 4:
        return ReviewStep(
          lifeContext: _lifeContext,
          selectedGoals: _selectedGoals,
          onSubmit: _handleSubmit,
          onBack: _handleBack,
          submitting: _submitting,
        );
      default:
        return const Center(child: Text('Unknown step'));
    }
  }
}

