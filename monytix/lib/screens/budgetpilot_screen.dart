import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/budget_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_progress.dart';
import '../widgets/charts/premium_pie_chart.dart';
import '../theme/premium_theme.dart';
import '../animations/card_animations.dart';

class BudgetPilotScreen extends StatefulWidget {
  const BudgetPilotScreen({super.key});

  @override
  State<BudgetPilotScreen> createState() => _BudgetPilotScreenState();
}

class _BudgetPilotScreenState extends State<BudgetPilotScreen> {
  final BudgetService _budgetService = BudgetService(ApiService());
  bool _isLoading = true;
  List<dynamic> _recommendations = [];
  Map<String, dynamic>? _committedBudget;
  Map<String, dynamic>? _variance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _committing = false;

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final recommendationsRes = await _budgetService.getRecommendations();
      final committedRes = await _budgetService.getCommittedBudget();
      if (!mounted) return;
      setState(() {
        // Safely parse recommendations list - handle different response formats
        if (recommendationsRes is Map<String, dynamic>) {
          final recsData = recommendationsRes['recommendations'];
          if (recsData is List) {
            _recommendations = List<dynamic>.from(recsData);
          } else {
            _recommendations = [];
          }
        } else if (recommendationsRes is List) {
          _recommendations = List<dynamic>.from(recommendationsRes as Iterable);
        } else {
          _recommendations = [];
        }
        
        // Safely parse committed budget - handle different response formats
        if (committedRes is Map<String, dynamic>) {
          final budgetData = committedRes['budget'];
          if (budgetData is Map<String, dynamic>) {
            _committedBudget = budgetData;
          } else {
            _committedBudget = null;
          }
        } else {
          _committedBudget = null;
        }
        
        _isLoading = false;
        debugPrint('BudgetPilot: Loaded ${_recommendations.length} recommendations, committed budget: ${_committedBudget != null}');
      });
    } catch (e) {
      debugPrint('BudgetPilot: Error loading data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _recommendations = [];
        _committedBudget = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _commitBudget(String planCode) async {
    setState(() => _committing = true);
    try {
      await _budgetService.commitBudget(planCode: planCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget committed successfully!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error committing budget: $e')),
        );
      }
    } finally {
      setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BudgetPilot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: PremiumTheme.goldPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BudgetPilot',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: -0.2, end: 0),
                        const SizedBox(height: 8),
                        Text(
                          'Smart budget recommendations tailored to your spending patterns and goals',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms, delay: 100.ms)
                            .slideX(begin: -0.2, end: 0),
                        const SizedBox(height: 24),
                        if (_committedBudget != null) ...[
                          _buildCommittedBudgetCard(),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          _committedBudget != null ? 'Other Recommendations' : 'Recommended Budget Plans',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms, delay: 200.ms)
                            .slideX(begin: -0.2, end: 0),
                        const SizedBox(height: 12),
                        _buildRecommendationsList(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Widget _buildCommittedBudgetCard() {
    final budget = _committedBudget!;
    final needsPct = _parseDouble(budget['alloc_needs_pct']);
    final wantsPct = _parseDouble(budget['alloc_wants_pct']);
    final assetsPct = _parseDouble(budget['alloc_assets_pct']);
    final goalAllocations = budget['goal_allocations'] is List 
        ? (budget['goal_allocations'] as List) 
        : [];
    
    // Prepare chart data
    final List<ChartData> budgetData = [
      ChartData(label: 'Needs', value: needsPct * 100, color: Colors.orange),
      ChartData(label: 'Wants', value: wantsPct * 100, color: Colors.purple),
      ChartData(label: 'Savings', value: assetsPct * 100, color: Colors.blue),
    ];
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: Colors.green.withOpacity(0.5),
      borderWidth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                'Your Committed Budget',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          )
              .animate()
              .fadeInSlideUp(),
          const SizedBox(height: 20),
          // Pie chart
          if (budgetData.isNotEmpty)
            PremiumPieChart(
              data: budgetData,
              size: 200,
              title: 'Budget Allocation',
              subtitle: 'Your committed budget breakdown',
            )
                .animate()
                .fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 20),
          // Allocation bars
          Row(
            children: [
              Expanded(
                child: _buildAllocationBar('Needs', needsPct, Colors.orange)
                    .animate()
                    .fadeInSlideUp(delay: 200.ms),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAllocationBar('Wants', wantsPct, Colors.purple)
                    .animate()
                    .fadeInSlideUp(delay: 250.ms),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAllocationBar('Savings', assetsPct, Colors.blue)
                    .animate()
                    .fadeInSlideUp(delay: 300.ms),
              ),
            ],
          ),
          // Goal allocations
          if (goalAllocations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Goal Allocations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            )
                .animate()
                .fadeInSlideUp(delay: 400.ms),
            const SizedBox(height: 12),
            ...goalAllocations.asMap().entries.map((entry) {
              final index = entry.key;
              final alloc = entry.value;
              final allocMap = alloc is Map<String, dynamic> ? alloc : <String, dynamic>{};
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        allocMap['goal_name']?.toString() ?? 
                             allocMap['goal_id']?.toString() ?? 'Goal',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '₹${_formatNumber(allocMap['planned_amount'] ?? 0)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeInSlideUp(delay: (400 + index * 50).ms);
            }),
          ],
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  Widget _buildAllocationBar(String label, double pct, Color color) {
    return Column(
      children: [
        AnimatedProgress(
          value: pct.clamp(0.0, 1.0),
          color: color,
          height: 10,
          borderRadius: 8,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    return numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }


  Widget _buildRecommendationsList() {
    if (_recommendations.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.recommend_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No recommendations available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeInSlideUp();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final rec = _recommendations[index] as Map<String, dynamic>;
        final planCode = rec['plan_code']?.toString() ?? '';
        final isCommitted = _committedBudget != null && 
            _committedBudget!['plan_code']?.toString() == planCode;
        final needsPct = _parseDouble(rec['needs_budget_pct']);
        final wantsPct = _parseDouble(rec['wants_budget_pct']);
        final savingsPct = _parseDouble(rec['savings_budget_pct']);
        final goalPreview = rec['goal_preview'] is List 
            ? (rec['goal_preview'] as List) 
            : [];
        
        // Prepare chart data for recommendation
        final List<ChartData> recBudgetData = [
          ChartData(label: 'Needs', value: needsPct * 100, color: Colors.orange),
          ChartData(label: 'Wants', value: wantsPct * 100, color: Colors.purple),
          ChartData(label: 'Savings', value: savingsPct * 100, color: Colors.blue),
        ];
        
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          borderColor: isCommitted
              ? Colors.green.withOpacity(0.5)
              : PremiumTheme.goldPrimary.withOpacity(0.3),
          borderWidth: isCommitted ? 2 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      rec['name']?.toString() ?? 'Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
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
                      'Score: ${_parseDouble(rec['score']).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: PremiumTheme.goldPrimary,
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 100).ms),
              if (rec['description'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  rec['description']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 50).ms),
              ],
              const SizedBox(height: 20),
              // Pie chart for allocation
              if (recBudgetData.isNotEmpty)
                PremiumPieChart(
                  data: recBudgetData,
                  size: 180,
                  title: 'Allocation',
                  subtitle: 'Budget breakdown',
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 100).ms),
              const SizedBox(height: 16),
              // Allocation bars
              Row(
                children: [
                  Expanded(
                    child: _buildAllocationBar('Needs', needsPct, Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAllocationBar('Wants', wantsPct, Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAllocationBar('Savings', savingsPct, Colors.blue),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 100 + 200).ms),
              if (rec['recommendation_reason'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  rec['recommendation_reason']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 250).ms),
              ],
              // Goal preview
              if (goalPreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Goal Allocation Preview',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 300).ms),
                const SizedBox(height: 8),
                ...goalPreview.take(3).toList().asMap().entries.map((entry) {
                  final goalIndex = entry.key;
                  final goal = entry.value;
                  final goalMap = goal is Map<String, dynamic> ? goal : <String, dynamic>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goalMap['goal_name']?.toString() ?? 'Goal',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${_formatNumber(goalMap['allocation_amount'] ?? 0)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeInSlideUp(delay: (index * 100 + 350 + goalIndex * 50).ms);
                }),
              ],
              const SizedBox(height: 16),
              if (isCommitted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '✓ Committed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 400).ms)
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _committing ? null : () => _commitBudget(planCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.goldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_committing ? 'Committing...' : 'Commit to This Plan'),
                  ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 100 + 400).ms),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(delay: (index * 100).ms);
      },
    );
  }

}

