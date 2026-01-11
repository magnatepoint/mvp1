import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/spendsense_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/charts/premium_pie_chart.dart';
import '../widgets/animated_progress.dart';
import '../theme/premium_theme.dart';
import '../animations/card_animations.dart';

class SpendSenseScreen extends StatefulWidget {
  const SpendSenseScreen({super.key});

  @override
  State<SpendSenseScreen> createState() => _SpendSenseScreenState();
}

class _SpendSenseScreenState extends State<SpendSenseScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final SpendSenseService _spendSenseService = SpendSenseService(ApiService());
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _kpiLoading = true;
  bool _transactionsLoading = true;
  bool _insightsLoading = false;
  bool _uploading = false;
  bool _pickingFile = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  String? _pdfPassword;
  
  Map<String, dynamic>? _kpis;
  List<dynamic> _transactions = [];
  Map<String, dynamic>? _insights;
  int _totalCount = 0;
  int _currentPage = 1;
  String? _selectedMonth;
  List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadKPIs(),
        _loadTransactions(),
        _loadAvailableMonths(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadKPIs() async {
    setState(() => _kpiLoading = true);
    try {
      final kpis = await _spendSenseService.getKPIs(month: _selectedMonth);
      setState(() {
        _kpis = kpis;
        _kpiLoading = false;
      });
    } catch (e) {
      setState(() => _kpiLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _transactionsLoading = true);
    try {
      final result = await _spendSenseService.getTransactions(limit: 25, offset: (_currentPage - 1) * 25);
      setState(() {
        // Ensure transactions is a List
        final transactionsData = result['transactions'];
        if (transactionsData is List) {
          _transactions = transactionsData;
        } else {
          _transactions = [];
        }
        // Parse total count safely
        final totalData = result['total'];
        _totalCount = totalData is int ? totalData : (totalData is num ? totalData.toInt() : 0);
        _transactionsLoading = false;
      });
    } catch (e) {
      setState(() => _transactionsLoading = false);
    }
  }

  Future<void> _loadInsights() async {
    setState(() => _insightsLoading = true);
    try {
      final insights = await _spendSenseService.getInsights();
      setState(() {
        _insights = insights;
        _insightsLoading = false;
      });
    } catch (e) {
      setState(() => _insightsLoading = false);
    }
  }

  Future<void> _loadAvailableMonths() async {
    try {
      final months = await _spendSenseService.getAvailableMonths();
      setState(() => _availableMonths = months);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SpendSense'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: PremiumTheme.goldPrimary,
          labelColor: PremiumTheme.goldPrimary,
          tabs: const [
            Tab(text: 'KPIs'),
            Tab(text: 'Insights'),
            Tab(text: 'Transactions'),
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
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 48), // App bar + tab bar height
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.goldPrimary),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKPIsTab(),
                    _buildInsightsTab(),
                    _buildTransactionsTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildKPIsTab() {
    return RefreshIndicator(
      onRefresh: _loadKPIs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month filter
            if (_availableMonths.isNotEmpty) _buildMonthFilter(),
            const SizedBox(height: 16),
            if (_kpiLoading)
              const Center(child: CircularProgressIndicator())
            else if (_kpis != null)
              _buildKPIContent(_kpis!)
            else
              const Center(child: Text('No KPI data available')),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthFilter() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('Month: '),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedMonth,
              isExpanded: true,
              hint: const Text('Latest Available'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Latest Available'),
                ),
                ..._availableMonths.map((month) {
                  final date = DateTime.parse('$month-01');
                  return DropdownMenuItem<String>(
                    value: month,
                    child: Text(
                      '${_getMonthName(date.month)} ${date.year}',
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMonth = value;
                });
                _loadKPIs();
              },
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildKPIContent(Map<String, dynamic> kpis) {
    // Prepare chart data
    final needs = _parseDouble(kpis['needs_amount']) ?? 0.0;
    final wants = _parseDouble(kpis['wants_amount']) ?? 0.0;
    final assets = _parseDouble(kpis['assets_amount']) ?? 0.0;
    
    List<ChartData> expenseData = [];
    if (needs > 0 || wants > 0 || assets > 0) {
      expenseData = [
        ChartData(label: 'Needs', value: needs, color: Colors.green),
        ChartData(label: 'Wants', value: wants, color: Colors.orange),
        ChartData(label: 'Savings', value: assets, color: Colors.blue),
      ];
    }
    
    return Column(
      children: [
        // Main KPI cards
        Row(
          children: [
            Expanded(
              child: PremiumStatCard(
                label: 'Income',
                value: '₹${_formatNumber(kpis['income_amount'] ?? 0)}',
                icon: Icons.trending_up,
                color: Colors.green,
                index: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumStatCard(
                label: 'Needs',
                value: '₹${_formatNumber(kpis['needs_amount'] ?? 0)}',
                icon: Icons.shield,
                color: Colors.orange,
                index: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PremiumStatCard(
                label: 'Wants',
                value: '₹${_formatNumber(kpis['wants_amount'] ?? 0)}',
                icon: Icons.shopping_bag,
                color: Colors.purple,
                index: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumStatCard(
                label: 'Assets',
                value: '₹${_formatNumber(kpis['assets_amount'] ?? 0)}',
                icon: Icons.savings,
                color: Colors.blue,
                index: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Expense breakdown chart
        if (expenseData.isNotEmpty)
          PremiumPieChart(
            data: expenseData,
            size: 220,
            title: 'Expense Breakdown',
            subtitle: 'Spending by category',
          )
              .animate()
              .fadeInSlideUp(delay: 200.ms),
        const SizedBox(height: 24),
        // Wants gauge
        if (kpis['wants_gauge'] != null) _buildWantsGauge(kpis['wants_gauge']),
        const SizedBox(height: 24),
        // Top categories
        if (kpis['top_categories'] != null && (kpis['top_categories'] as List).isNotEmpty)
          _buildTopCategories(kpis['top_categories']),
      ],
    );
  }
  
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }


  Widget _buildWantsGauge(Map<String, dynamic> gauge) {
    final ratio = (gauge['ratio'] ?? 0.0) as double;
    final percent = (ratio * 100).toInt();
    final thresholdCrossed = gauge['threshold_crossed'] ?? false;
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Wants vs Needs',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 14,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    thresholdCrossed ? Colors.red : Colors.orange,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Wants',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            gauge['label'] ?? 'Chill Mode',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  Widget _buildTopCategories(List<dynamic> categories) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final share = (cat['share'] ?? 0.0) as double;
            final changePct = cat['change_pct'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat['category_name'] ?? cat['category_code'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${(share * 100).toStringAsFixed(1)}% share • ${cat['txn_count'] ?? 0} txns',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_formatNumber(cat['spend_amount'] ?? 0)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (changePct != null)
                        Text(
                          '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: changePct >= 0 ? Colors.red : Colors.green,
                              ),
                        ),
                    ],
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms),
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  Widget _buildInsightsTab() {
    if (_insights == null && !_insightsLoading) {
      return Center(
        child: ElevatedButton(
          onPressed: _loadInsights,
          child: const Text('Load Insights'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: _insightsLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _insights != null
                  ? _buildInsightsContent(_insights!)
                  : const Center(child: Text('No insights available')),
            ),
    );
  }

  Widget _buildInsightsContent(Map<String, dynamic> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insights['category_breakdown'] != null)
          _buildCategoryBreakdown(insights['category_breakdown']),
        const SizedBox(height: 24),
        if (insights['recurring_transactions'] != null)
          _buildRecurringTransactions(insights['recurring_transactions']),
      ],
    );
  }

  Widget _buildCategoryBreakdown(List<dynamic> breakdown) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...breakdown.take(10).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final percentage = (cat['percentage'] ?? 0.0) as double;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat['category_name'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '₹${_formatNumber(cat['amount'] ?? 0)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedProgress(
                    value: percentage / 100,
                    color: PremiumTheme.goldPrimary,
                    height: 8,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}% • ${cat['transaction_count'] ?? 0} transactions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms),
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  Widget _buildRecurringTransactions(List<dynamic> recurring) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurring Transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...recurring.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: PremiumTheme.goldPrimary.withOpacity(0.2),
                child: const Icon(Icons.repeat, color: PremiumTheme.goldPrimary),
              ),
              title: Text(item['merchant_name'] ?? 'Unknown'),
              subtitle: Text(
                '${item['category_name'] ?? ''} • ${item['frequency'] ?? ''}',
              ),
              trailing: Text(
                '₹${_formatNumber(item['avg_amount'] ?? 0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            )
                .animate()
                .fadeInSlideUp(delay: (index * 50).ms);
          }),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  Future<void> _uploadFile() async {
    try {
      setState(() {
        _uploadError = null;
        _pickingFile = true;
      });
      
      debugPrint('Opening file picker...');
      
      // On macOS, ensure the window is active before opening file picker
      // Use a longer delay and ensure the app is in focus
      if (Platform.isMacOS) {
        // Give the UI time to settle
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Try to bring window to front by requesting focus
        if (mounted) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
          FocusScope.of(context).requestFocus(FocusNode());
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      if (!mounted) {
        setState(() => _pickingFile = false);
        return;
      }
      
      // Use FileType.custom with explicit extensions - most reliable on macOS
      debugPrint('Opening file picker dialog...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'csv', 'xls', 'xlsx'],
        allowMultiple: false,
        dialogTitle: Platform.isMacOS ? null : 'Select a statement file', // macOS doesn't always respect this
      );
      
      debugPrint('File picker completed. Result: ${result != null ? "file selected" : "cancelled"}');
      
      if (!mounted) return;
      
      setState(() {
        _pickingFile = false;
      });
      
      if (result == null || result.files.isEmpty) {
        debugPrint('File picker cancelled or no file selected');
        return;
      }
      
      final pickedFile = result.files.first;
      debugPrint('Selected file: ${pickedFile.name}, path: ${pickedFile.path}');
      
      // Validate file extension
      final fileName = pickedFile.name.toLowerCase();
      final validExtensions = ['.pdf', '.csv', '.xls', '.xlsx'];
      final hasValidExtension = validExtensions.any((ext) => fileName.endsWith(ext));
      
      if (!hasValidExtension) {
        debugPrint('Invalid file type: ${pickedFile.name}');
        setState(() {
          _uploadError = 'Please select a PDF, CSV, or Excel file';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a PDF, CSV, or Excel file'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Process the selected file
      if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final file = File(pickedFile.path!);
        if (await file.exists()) {
          debugPrint('File exists, starting upload...');
          await _handleFileUpload(file);
        } else {
          debugPrint('File does not exist at path: ${pickedFile.path}');
          setState(() {
            _uploadError = 'Selected file does not exist';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected file does not exist'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('File path is null or empty');
        setState(() {
          _uploadError = 'Could not access file path. Please try again.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access file path. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('File picker error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _uploadError = 'Failed to pick file: $e';
        _pickingFile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file picker: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleFileUpload(File file) async {
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      await _spendSenseService.uploadFile(
        file,
        password: _pdfPassword?.isNotEmpty == true ? _pdfPassword : null,
        onProgress: (sent, total) {
          setState(() {
            _uploadProgress = (sent / total) * 100;
          });
        },
      );

      // Reset password field
      setState(() {
        _pdfPassword = null;
      });

      // Refresh data after successful upload
      await Future.wait([
        _loadTransactions(),
        _loadKPIs(),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Widget _buildTransactionsTab() {
    if (_transactionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Upload section
            _buildUploadSection(),
            // Transactions list
            if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No transactions found')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                itemBuilder: (context, index) {
                  final txn = _transactions[index] as Map<String, dynamic>;
                  final isDebit = txn['direction'] == 'debit';
                  final merchant = txn['merchant'] ?? txn['merchant_name_norm'] ?? txn['description'] ?? 'Transaction';
                  final category = txn['category'] ?? txn['category_code'] ?? 'Uncategorized';
                  final subcategory = txn['subcategory'] ?? txn['subcategory_code'];
                  final amount = _parseAmount(txn['amount']);
                  
                  // Build subtitle with category and subcategory
                  String subtitle = category.toString();
                  if (subcategory != null && subcategory.toString().isNotEmpty) {
                    subtitle += ' • ${subcategory.toString()}';
                  }
                  subtitle += ' • ${_formatDate(txn['txn_date'])}';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDebit
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      child: Icon(
                        isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(merchant.toString()),
                    subtitle: Text(subtitle),
                    trailing: Text(
                      '${isDebit ? '-' : '+'}₹${_formatNumber(amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                  );
                },
              ),
            if (_totalCount > 25) _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: PremiumTheme.goldPrimary),
              const SizedBox(width: 8),
              Text(
                'Upload Statement',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
            const SizedBox(height: 12),
            const Text(
              'Upload PDF, CSV, or Excel files to import transactions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            // PDF password field
            TextField(
              controller: TextEditingController(text: _pdfPassword),
              decoration: const InputDecoration(
                labelText: 'PDF Password (optional)',
                hintText: 'Enter password if PDF is encrypted',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                filled: true,
              ),
              obscureText: true,
              enabled: !_uploading,
              onChanged: (value) {
                setState(() {
                  _pdfPassword = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // Upload button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_uploading || _pickingFile) ? null : _uploadFile,
                icon: (_uploading || _pickingFile)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_uploading
                    ? 'Uploading... ${_uploadProgress.toStringAsFixed(0)}%'
                    : _pickingFile
                        ? 'Opening file picker...'
                        : 'Select File to Upload'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            // Upload progress
            if (_uploading && _uploadProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_uploadProgress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            // Error message
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / 25).ceil();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadTransactions();
                  }
                : null,
          ),
          Text('Page $_currentPage of $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadTransactions();
                  }
                : null,
          ),
        ],
      ),
    )
        .animate()
        .fadeInSlideUp();
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final numValue = _parseAmount(value);
    return numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day} ${_getMonthName(date.month)}';
    } catch (e) {
      return dateStr.toString();
    }
  }
}

