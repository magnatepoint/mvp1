import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/console_service.dart';
import '../services/goals_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/animated_progress.dart';
import '../widgets/animated_gradient.dart';
import '../widgets/charts/premium_pie_chart.dart';
import '../widgets/charts/premium_donut_chart.dart';
import '../theme/premium_theme.dart';
import '../animations/card_animations.dart';

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final ConsoleService _consoleService = ConsoleService(ApiService());
  final GoalsService _goalsService = GoalsService(ApiService());
  
  bool _isLoading = true;
  String? _error;
  
  // KPI Data
  Map<String, dynamic>? _kpis;
  
  // Budget Data
  Map<String, dynamic>? _budgetVariance;
  
  // Goals Data
  Map<String, dynamic>? _goalsProgress;
  
  // Transactions Data
  List<dynamic> _recentTransactions = [];
  
  // Money Moments Data
  List<dynamic> _moneyMoments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _consoleService.getKPIs(),
        _consoleService.getBudgetVariance(),
        _goalsService.getGoalProgress(),
        _consoleService.getRecentTransactions(limit: 5),
        _consoleService.getMoneyMoments(),
      ]);

      setState(() {
        _kpis = results[0] as Map<String, dynamic>?;
        _budgetVariance = results[1] as Map<String, dynamic>?;
        _goalsProgress = results[2] as Map<String, dynamic>?;
        _recentTransactions = results[3] as List<dynamic>;
        _moneyMoments = results[4] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading console data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Monytix Console'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.goldPrimary),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Container(
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
                  child: Padding(
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
                          // Financial Health Summary Card
                          _buildFinancialHealthCard(context),
                          const SizedBox(height: 16),

                          // Quick Stats Row
                          _buildQuickStatsRow(context),
                          const SizedBox(height: 16),

                          // Charts Section
                          _buildChartsSection(context),
                          const SizedBox(height: 16),

                          // Active Goals Section
                          _buildActiveGoalsSection(context),
                          const SizedBox(height: 16),

                          // Budget Status Section
                          _buildBudgetStatusSection(context),
                          const SizedBox(height: 16),

                          // Recent Activity Section
                          _buildRecentActivitySection(context),
                          const SizedBox(height: 16),

                          // Money Moments / Insights Section
                          _buildInsightsSection(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
  
  Widget _buildChartsSection(BuildContext context) {
    // Prepare chart data from KPIs
    List<ChartData> expenseData = [];
    List<ChartData> budgetData = [];
    
    if (_kpis != null) {
      final needs = _parseDouble(_kpis!['needs_amount']) ?? 0.0;
      final wants = _parseDouble(_kpis!['wants_amount']) ?? 0.0;
      final assets = _parseDouble(_kpis!['assets_amount']) ?? 0.0;
      
      if (needs > 0 || wants > 0 || assets > 0) {
        expenseData = [
          ChartData(
            label: 'Needs',
            value: needs,
            color: Colors.green,
          ),
          ChartData(
            label: 'Wants',
            value: wants,
            color: Colors.orange,
          ),
          ChartData(
            label: 'Savings',
            value: assets,
            color: Colors.blue,
          ),
        ];
      }
    }
    
    if (_budgetVariance != null && _budgetVariance is Map<String, dynamic>) {
      final aggregate = _budgetVariance!['aggregate'];
      if (aggregate is Map<String, dynamic>) {
        final plannedNeeds = _parseDouble(aggregate['planned_needs_amt']) ?? 0.0;
        final plannedWants = _parseDouble(aggregate['planned_wants_amt']) ?? 0.0;
        final plannedAssets = _parseDouble(aggregate['planned_assets_amt']) ?? 0.0;
        
        if (plannedNeeds > 0 || plannedWants > 0 || plannedAssets > 0) {
          budgetData = [
            ChartData(
              label: 'Needs',
              value: plannedNeeds,
              color: Colors.green,
            ),
            ChartData(
              label: 'Wants',
              value: plannedWants,
              color: Colors.orange,
            ),
            ChartData(
              label: 'Savings',
              value: plannedAssets,
              color: Colors.blue,
            ),
          ];
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visualizations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideX(begin: -0.2, end: 0),
        const SizedBox(height: 16),
        if (expenseData.isNotEmpty) ...[
          PremiumPieChart(
            data: expenseData,
            size: 200,
            title: 'Expense Breakdown',
            subtitle: 'Spending by category',
          )
              .animate()
              .fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 16),
        ],
        if (budgetData.isNotEmpty) ...[
          PremiumDonutChart(
            data: budgetData,
            size: 200,
            title: 'Budget Allocation',
            subtitle: 'Planned budget distribution',
            centerWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Budget',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  'Plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          )
              .animate()
              .fadeInSlideUp(delay: 200.ms),
        ],
      ],
    );
  }

  Widget _buildFinancialHealthCard(BuildContext context) {
    // Calculate balance and this month from KPIs
    double balance = 0.0;
    double thisMonth = 0.0;
    String healthStatus = 'Good';
    Color statusColor = Colors.green;
    
    if (_kpis != null) {
      final income = _parseDouble(_kpis!['income_amount']) ?? 0.0;
      final needs = _parseDouble(_kpis!['needs_amount']) ?? 0.0;
      final wants = _parseDouble(_kpis!['wants_amount']) ?? 0.0;
      final assets = _parseDouble(_kpis!['assets_amount']) ?? 0.0;
      
      // Balance = Assets (savings) or income - expenses
      balance = assets > 0 ? assets : (income - needs - wants);
      thisMonth = income - needs - wants;
      
      // Determine health status
      if (thisMonth > 0) {
        healthStatus = 'Good';
        statusColor = Colors.green;
      } else if (thisMonth > -income * 0.1) {
        healthStatus = 'Fair';
        statusColor = Colors.orange;
      } else {
        healthStatus = 'Needs Attention';
        statusColor = Colors.red;
      }
    }
    
    return AnimatedGradient(
      colors: PremiumTheme.goldGradient,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 24,
        blur: 15,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Financial Health',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    healthStatus,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .scale(delay: 100.ms, begin: const Offset(0.8, 0.8)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  'Balance',
                  _formatCurrency(balance),
                  Colors.white,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                _buildStatItem(
                  context,
                  'This Month',
                  _formatCurrency(thisMonth),
                  Colors.white.withOpacity(0.9),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeInSlideUp();
  }
  
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
  
  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsRow(BuildContext context) {
    // Calculate from KPIs
    double income = 0.0;
    double expenses = 0.0;
    double savings = 0.0;
    
    if (_kpis != null) {
      income = _parseDouble(_kpis!['income_amount']) ?? 0.0;
      final needs = _parseDouble(_kpis!['needs_amount']) ?? 0.0;
      final wants = _parseDouble(_kpis!['wants_amount']) ?? 0.0;
      final assets = _parseDouble(_kpis!['assets_amount']) ?? 0.0;
      
      expenses = needs + wants;
      savings = assets > 0 ? assets : (income - expenses);
    }
    
    return Row(
      children: [
        Expanded(
          child: PremiumStatCard(
            label: 'Income',
            value: _formatCurrency(income),
            icon: Icons.trending_up,
            color: Colors.green,
            index: 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumStatCard(
            label: 'Expenses',
            value: _formatCurrency(expenses),
            icon: Icons.trending_down,
            color: Colors.orange,
            index: 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumStatCard(
            label: 'Savings',
            value: _formatCurrency(savings),
            icon: Icons.savings,
            color: Colors.blue,
            index: 2,
          ),
        ),
      ],
    );
  }


  Widget _buildActiveGoalsSection(BuildContext context) {
    // Extract goals from progress data
    List<dynamic> goals = [];
    if (_goalsProgress != null && _goalsProgress is Map<String, dynamic>) {
      final goalsData = _goalsProgress!['goals'];
      if (goalsData is List) {
        goals = goalsData.take(2).toList(); // Show top 2 goals
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Goals',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigation handled by bottom nav bar
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: goals.isEmpty
              ? _buildEmptyState(
                  context,
                  icon: Icons.flag_outlined,
                  message: 'No goals set up yet.',
                  actionText: 'Set up your financial goals to start tracking progress.',
                )
              : Column(
                  children: goals.asMap().entries.map((entry) {
                final index = entry.key;
                final goal = entry.value;
                if (goal is! Map<String, dynamic>) return const SizedBox.shrink();
                
                final goalName = goal['goal_name']?.toString() ?? 'Unnamed Goal';
                final estimatedCost = _parseDouble(goal['estimated_cost']) ?? 0.0;
                final currentSavings = _parseDouble(goal['current_savings_close']) ?? 0.0;
                final progressPct = _parseDouble(goal['progress_pct']) ?? 0.0;
                final progress = progressPct / 100.0;
                
                // Use different colors for different goals
                final colors = [Colors.blue, Colors.purple, Colors.green, Colors.orange];
                final color = colors[index % colors.length];
                
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 24),
                    _buildGoalItem(
                      context,
                      goalName,
                      _formatCurrency(estimatedCost),
                      _formatCurrency(currentSavings),
                      progress,
                      color,
                    ),
                  ],
                );
              }).toList(),
                  ),
        )
            .animate()
            .fadeInSlideUp(),
      ],
    );
  }
  
  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? actionText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null) ...[
            const SizedBox(height: 4),
            Text(
              actionText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalItem(
    BuildContext context,
    String name,
    String target,
    String current,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '$current / $target',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedProgress(
          value: progress,
          color: color,
          height: 10,
          borderRadius: 8,
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% Complete',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildBudgetStatusSection(BuildContext context) {
    // Extract budget data from variance
    Map<String, double> budgetData = {};
    if (_budgetVariance != null && _budgetVariance is Map<String, dynamic>) {
      final aggregate = _budgetVariance!['aggregate'];
      if (aggregate is Map<String, dynamic>) {
        final needsAmt = _parseDouble(aggregate['needs_amt']) ?? 0.0;
        final plannedNeeds = _parseDouble(aggregate['planned_needs_amt']) ?? 0.0;
        final wantsAmt = _parseDouble(aggregate['wants_amt']) ?? 0.0;
        final plannedWants = _parseDouble(aggregate['planned_wants_amt']) ?? 0.0;
        final assetsAmt = _parseDouble(aggregate['assets_amt']) ?? 0.0;
        final plannedAssets = _parseDouble(aggregate['planned_assets_amt']) ?? 0.0;
        
        budgetData = {
          'needs_amt': needsAmt,
          'planned_needs': plannedNeeds,
          'wants_amt': wantsAmt,
          'planned_wants': plannedWants,
          'assets_amt': assetsAmt,
          'planned_assets': plannedAssets,
        };
      }
    }
    
    // If no budget data, try to use KPIs
    if (budgetData.isEmpty && _kpis != null) {
      final needs = _parseDouble(_kpis!['needs_amount']) ?? 0.0;
      final wants = _parseDouble(_kpis!['wants_amount']) ?? 0.0;
      final assets = _parseDouble(_kpis!['assets_amount']) ?? 0.0;
      
      budgetData = {
        'needs_amt': needs,
        'planned_needs': needs, // Use actual as planned if no budget
        'wants_amt': wants,
        'planned_wants': wants,
        'assets_amt': assets,
        'planned_assets': assets,
      };
    }
    
    final needsRatio = budgetData.isEmpty || budgetData['planned_needs'] == null || budgetData['planned_needs']! <= 0
        ? 0.0
        : budgetData['needs_amt']! / budgetData['planned_needs']!;
    final wantsRatio = budgetData.isEmpty || budgetData['planned_wants'] == null || budgetData['planned_wants']! <= 0
        ? 0.0
        : budgetData['wants_amt']! / budgetData['planned_wants']!;
    final assetsRatio = budgetData.isEmpty || budgetData['planned_assets'] == null || budgetData['planned_assets']! <= 0
        ? 0.0
        : budgetData['assets_amt']! / budgetData['planned_assets']!;
    
    if (budgetData.isEmpty) {
      // Show empty state for budget
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {
                  // Navigation handled by bottom nav bar
                },
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: _buildEmptyState(
              context,
              icon: Icons.account_balance_wallet_outlined,
              message: 'No budget set up yet.',
              actionText: 'Create a budget to track your spending against your plan.',
            ),
          )
              .animate()
              .fadeInSlideUp(),
        ],
      );
    }
    
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigation handled by bottom nav bar
              },
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBudgetItem(
                context,
                'Needs',
                _formatCurrency(budgetData['planned_needs'] ?? 0.0),
                _formatCurrency(budgetData['needs_amt'] ?? 0.0),
                needsRatio,
                Colors.green,
              )
                  .animate()
                  .fadeInSlideUp(delay: 100.ms),
              const SizedBox(height: 12),
              _buildBudgetItem(
                context,
                'Wants',
                _formatCurrency(budgetData['planned_wants'] ?? 0.0),
                _formatCurrency(budgetData['wants_amt'] ?? 0.0),
                wantsRatio,
                Colors.orange,
              )
                  .animate()
                  .fadeInSlideUp(delay: 200.ms),
              const SizedBox(height: 12),
              _buildBudgetItem(
                context,
                'Savings',
                _formatCurrency(budgetData['planned_assets'] ?? 0.0),
                _formatCurrency(budgetData['assets_amt'] ?? 0.0),
                assetsRatio,
                Colors.blue,
              )
                  .animate()
                  .fadeInSlideUp(delay: 300.ms),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      ],
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    String category,
    String budget,
    String spent,
    double ratio,
    Color color,
  ) {
    final isOver = ratio > 1.0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹$spent / ₹$budget',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOver ? Colors.red.withOpacity(0.1) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOver ? '${(ratio * 100).toInt()}%' : '${(ratio * 100).toInt()}%',
            style: TextStyle(
              color: isOver ? Colors.red : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigation handled by bottom nav bar
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: _recentTransactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildEmptyState(
                    context,
                    icon: Icons.receipt_long_outlined,
                    message: 'No transactions yet.',
                    actionText: 'Upload a statement to get started.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
              final txn = _recentTransactions[index];
              if (txn is! Map<String, dynamic>) return const SizedBox.shrink();
              
              final merchant = txn['merchant']?.toString() ?? 'Transaction';
              final amount = _parseDouble(txn['amount']) ?? 0.0;
              final direction = txn['direction']?.toString() ?? 'debit';
              final txnDate = txn['txn_date'];
              final isDebit = direction.toLowerCase() == 'debit';
              
              // Format date
              String dateStr = 'Today';
              if (txnDate != null) {
                try {
                  DateTime date;
                  if (txnDate is String) {
                    date = DateTime.parse(txnDate);
                  } else if (txnDate is DateTime) {
                    date = txnDate;
                  } else {
                    date = DateTime.parse(txnDate.toString());
                  }
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final txnDay = DateTime(date.year, date.month, date.day);
                  
                  if (txnDay == today) {
                    dateStr = 'Today';
                  } else if (txnDay == today.subtract(const Duration(days: 1))) {
                    dateStr = 'Yesterday';
                  } else {
                    dateStr = '${date.day}/${date.month}/${date.year}';
                  }
                } catch (e) {
                  dateStr = txnDate.toString();
                }
              }
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: (isDebit ? Colors.red : Colors.green).withOpacity(0.2),
                  child: Icon(
                    isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isDebit ? Colors.red : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(merchant),
                subtitle: Text(dateStr),
                trailing: Text(
                  '${isDebit ? '-' : '+'}${_formatCurrency(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDebit ? Colors.red : Colors.green,
                  ),
                ),
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms);
            },
                ),
        )
            .animate()
            .fadeInSlideUp(),
      ],
    );
  }

  Widget _buildInsightsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Money Moments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigation handled by bottom nav bar
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: _moneyMoments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildEmptyState(
                    context,
                    icon: Icons.lightbulb_outline,
                    message: 'No money moments yet.',
                    actionText: "We'll analyze your spending patterns soon.",
                  ),
                )
              : _buildMoneyMomentCard(context),
        )
            .animate()
            .fadeInSlideUp(),
      ],
    );
  }
  
  Widget _buildMoneyMomentCard(BuildContext context) {
    // Get first moment
    if (_moneyMoments.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.lightbulb_outline,
        message: 'No money moments yet.',
        actionText: "We'll analyze your spending patterns soon.",
      );
    }
    
    final moment = _moneyMoments[0];
    if (moment is! Map<String, dynamic>) {
      return _buildEmptyState(
        context,
        icon: Icons.lightbulb_outline,
        message: 'No money moments yet.',
        actionText: "We'll analyze your spending patterns soon.",
      );
    }
    
    final label = moment['label']?.toString() ?? 'Insight';
    final insightText = moment['insight_text']?.toString() ?? 
                        moment['description']?.toString() ?? 
                        'No insight available';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.amber),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  insightText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

