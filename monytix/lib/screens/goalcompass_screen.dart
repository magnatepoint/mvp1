import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/goals_service.dart';
import 'goals/goals_stepper_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_progress.dart';
import '../widgets/charts/premium_donut_chart.dart';
import '../widgets/charts/premium_pie_chart.dart';
import '../widgets/animated_gradient.dart';
import '../theme/premium_theme.dart';
import '../animations/card_animations.dart';

class GoalCompassScreen extends StatefulWidget {
  const GoalCompassScreen({super.key});

  @override
  State<GoalCompassScreen> createState() => _GoalCompassScreenState();
}

class _GoalCompassScreenState extends State<GoalCompassScreen> {
  final GoalsService _goalsService = GoalsService(ApiService());
  bool _isLoading = true;
  List<dynamic> _goals = [];
  Map<String, dynamic>? _progress;
  List<dynamic> _signals = [];
  List<dynamic> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _goalsService.getGoals();
      final progress = await _goalsService.getGoalProgress();
      final signals = await _goalsService.getSignals();
      final suggestions = await _goalsService.getSuggestions();
      setState(() {
        // Safely parse goals list
        _goals = goals is List ? goals : [];
        
        // Safely parse progress - handle both Map and List responses
        if (progress is Map<String, dynamic>) {
          _progress = progress;
        } else if (progress is List) {
          // If API returns list directly, wrap it in a Map
          _progress = {'goals': progress};
        } else {
          _progress = null;
        }
        
        // Safely parse signals list
        _signals = signals is List ? signals : [];
        // Safely parse suggestions list
        _suggestions = suggestions is List ? suggestions : [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading GoalCompass data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        final errorMessage = ApiService.getConnectionErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('GoalCompass'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: PremiumTheme.goldPrimary,
            labelColor: PremiumTheme.goldPrimary,
            tabs: const [
              Tab(text: 'Goals'),
              Tab(text: 'Signals'),
              Tab(text: 'Suggestions'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
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
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.goldPrimary),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 48), // App bar + tab bar height
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: PremiumTheme.goldPrimary,
                    child: TabBarView(
                      children: [
                        _buildGoalsTab(),
                        _buildSignalsTab(),
                        _buildSuggestionsTab(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGoalsTab() {
    // Safely extract goals list from progress
    List? goalsList;
    if (_progress != null && _progress is Map<String, dynamic>) {
      final goalsData = _progress!['goals'];
      if (goalsData is List) {
        goalsList = goalsData;
      }
    }
    
    if (_progress == null || goalsList == null || goalsList.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_outlined, size: 64, color: Colors.grey[400])
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(delay: 200.ms),
              const SizedBox(height: 16),
              Text(
                'No Goals Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Set up your financial goals first to start tracking progress.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GoalsStepperScreen(),
                    ),
                  );
                  // Refresh data after returning from stepper
                  if (result == true || mounted) {
                    _loadData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.goldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Set Up Goals'),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 500.ms)
                  .scale(delay: 500.ms, begin: const Offset(0.8, 0.8)),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      );
    }

    final goalsData = _progress!['goals'];
    final goals = goalsData is List ? goalsData : [];
    return Column(
      children: [
        // Header with Add New Goal button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Goals',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: -0.2, end: 0),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GoalsStepperScreen(),
                    ),
                  );
                  // Refresh data after returning from stepper
                  if (result == true || mounted) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Goal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.goldPrimary,
                  foregroundColor: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 100.ms)
                  .scale(delay: 100.ms, begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
        // Goals list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
        final goalData = goals[index];
        if (goalData is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        final goal = goalData;
        final progressPct = _parseDouble(goal['progress_pct']) ?? 0.0;
        final currentSavings = _parseDouble(goal['current_savings_close']) ?? 0.0;
        final remaining = _parseDouble(goal['remaining_amount']) ?? 0.0;
        final projectedDate = goal['projected_completion_date'];
        final milestones = goal['milestones'] is List ? (goal['milestones'] as List) : [];
        
        final totalAmount = currentSavings + remaining;
        final List<ChartData> progressData = totalAmount > 0
            ? [
                ChartData(
                  label: 'Completed',
                  value: currentSavings,
                  color: PremiumTheme.goldPrimary,
                ),
                ChartData(
                  label: 'Remaining',
                  value: remaining,
                  color: Colors.grey.withOpacity(0.3),
                ),
              ]
            : <ChartData>[];
        
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      goal['goal_name'] ?? 'Unnamed Goal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PremiumTheme.goldPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: PremiumTheme.goldPrimary.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${progressPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PremiumTheme.goldPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 100).ms),
              const SizedBox(height: 20),
              // Donut chart and details side by side
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 400;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Donut chart
                        if (progressData.isNotEmpty)
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: PremiumDonutChart(
                              data: progressData,
                              size: 120,
                              holeRadius: 0.7,
                              showLabels: false,
                              showLegend: false,
                              centerWidget: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${progressPct.toStringAsFixed(1)}%',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: PremiumTheme.goldPrimary,
                                          ),
                                    ),
                                    Text(
                                      'Complete',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: (index * 100 + 200).ms)
                              .scale(delay: (index * 100 + 200).ms, begin: const Offset(0.5, 0.5)),
                        const SizedBox(width: 20),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Current Savings:', _formatCurrency(currentSavings)),
                              const SizedBox(height: 8),
                              _buildDetailRow('Remaining:', _formatCurrency(remaining)),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Projected Completion:',
                                projectedDate != null
                                    ? _formatDate(projectedDate)
                                    : 'Calculating...',
                              ),
                            ],
                          )
                              .animate()
                              .fadeInSlideUp(delay: (index * 100 + 100).ms),
                        ),
                      ],
                    );
                  } else {
                    // Stack vertically on narrow screens
                    return Column(
                      children: [
                        if (progressData.isNotEmpty)
                          Center(
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: PremiumDonutChart(
                                data: progressData,
                                size: 120,
                                holeRadius: 0.7,
                                showLabels: false,
                                showLegend: false,
                                centerWidget: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${progressPct.toStringAsFixed(1)}%',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: PremiumTheme.goldPrimary,
                                            ),
                                      ),
                                      Text(
                                        'Complete',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: (index * 100 + 200).ms)
                              .scale(delay: (index * 100 + 200).ms, begin: const Offset(0.5, 0.5)),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Current Savings:', _formatCurrency(currentSavings)),
                            const SizedBox(height: 8),
                            _buildDetailRow('Remaining:', _formatCurrency(remaining)),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Projected Completion:',
                              projectedDate != null
                                  ? _formatDate(projectedDate)
                                  : 'Calculating...',
                            ),
                          ],
                        )
                            .animate()
                            .fadeInSlideUp(delay: (index * 100 + 100).ms),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              // Progress bar
              AnimatedProgress(
                value: (progressPct / 100).clamp(0.0, 1.0),
                color: progressPct >= 100 ? Colors.green : PremiumTheme.goldPrimary,
                height: 10,
                borderRadius: 8,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (index * 100 + 300).ms),
              // Milestones
              if (milestones.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Milestones Achieved:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (index * 100 + 400).ms),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: milestones.asMap().entries.map((entry) {
                    final milestoneIndex = entry.key;
                    final milestone = entry.value;
                    return Chip(
                      label: Text('$milestone%'),
                      backgroundColor: Colors.green.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide(
                        color: Colors.green.withOpacity(0.5),
                        width: 1.5,
                      ),
                    )
                        .animate()
                        .fadeInSlideUp(delay: (index * 100 + 500 + milestoneIndex * 50).ms);
                  }).toList(),
                ),
              ],
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(delay: (index * 100).ms);
      },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String _formatCurrency(dynamic value) {
    final numValue = _parseDouble(value) ?? 0;
    return '₹${numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildSignalsTab() {
    if (_signals.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No signals available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _signals.length,
      itemBuilder: (context, index) {
        final signalData = _signals[index];
        if (signalData is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        final signal = signalData;
        final signalType = signal['signal_type']?.toString() ?? 'Signal';
        final signalColor = _getSignalColor(signalType);
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: signalColor.withOpacity(0.2),
                radius: 24,
                child: Icon(
                  _getSignalIcon(signalType),
                  color: signalColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signalType,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signal['message']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: signalColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  signal['severity']?.toString() ?? 'info',
                  style: TextStyle(
                    color: signalColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No suggestions available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestionData = _suggestions[index];
        if (suggestionData is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        final suggestion = suggestionData;
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion['title']?.toString() ?? 'Suggestion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms),
              const SizedBox(height: 12),
              Text(
                suggestion['description']?.toString() ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50 + 50).ms),
              if (suggestion['action_text'] != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Handle action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.goldPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(suggestion['action_text']?.toString() ?? 'Action'),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 50 + 100).ms),
              ],
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(delay: (index * 50).ms);
      },
    );
  }

  Color _getSignalColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'alert':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSignalIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'alert':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
}

