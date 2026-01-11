import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/moneymoments_service.dart';
import '../widgets/glass_card.dart';
import '../theme/premium_theme.dart';
import '../animations/card_animations.dart';

class MoneyMomentsScreen extends StatefulWidget {
  const MoneyMomentsScreen({super.key});

  @override
  State<MoneyMomentsScreen> createState() => _MoneyMomentsScreenState();
}

class _MoneyMomentsScreenState extends State<MoneyMomentsScreen> {
  final MoneyMomentsService _momentsService = MoneyMomentsService(ApiService());
  bool _isLoading = true;
  List<dynamic> _moments = [];
  List<dynamic> _nudges = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _computing = false;
  bool _processingNudges = false;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final momentsRes = await _momentsService.getMoments();
      final nudgesRes = await _momentsService.getNudges();
      setState(() {
        _moments = momentsRes['moments'] ?? [];
        _nudges = nudgesRes['nudges'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _computeMoments() async {
    setState(() => _computing = true);
    try {
      final result = await _momentsService.computeMoments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Computed ${result['count'] ?? 0} money moments!'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error computing moments: $e')),
        );
      }
    } finally {
      setState(() => _computing = false);
    }
  }

  Future<void> _processNudges() async {
    setState(() => _processingNudges = true);
    try {
      // First compute signal
      try {
        await _momentsService.computeSignal();
      } catch (e) {
        // Continue even if signal computation fails
      }
      
      // Then evaluate rules
      final evalResult = await _momentsService.evaluateNudges();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluated ${evalResult['count'] ?? 0} nudge candidates'),
          ),
        );
      }
      
      // Then process and deliver
      final processResult = await _momentsService.processNudges(limit: 10);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processed and delivered ${processResult['count'] ?? 0} nudges!'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing nudges: $e')),
        );
      }
    } finally {
      setState(() => _processingNudges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('MoneyMoments'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: PremiumTheme.goldPrimary,
            labelColor: PremiumTheme.goldPrimary,
            tabs: const [
              Tab(text: 'Moments'),
              Tab(text: 'Nudges'),
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
                  child: Column(
                    children: [
                      // Action buttons header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _computing ? null : _computeMoments,
                                icon: const Icon(Icons.calculate),
                                label: Text(_computing ? 'Computing...' : 'Compute Moments'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PremiumTheme.goldPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            )
                                .animate()
                                .fadeInSlideUp(delay: 100.ms),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _processingNudges ? null : _processNudges,
                                icon: const Icon(Icons.notifications_active),
                                label: Text(
                                  _processingNudges ? 'Processing...' : 'Evaluate & Deliver Nudges',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            )
                                .animate()
                                .fadeInSlideUp(delay: 150.ms),
                          ],
                        ),
                      ),
                      // Tab content
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          color: PremiumTheme.goldPrimary,
                          child: TabBarView(
                            children: [
                              _buildMomentsTab(),
                              _buildNudgesTab(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMomentsTab() {
    if (_moments.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights_outlined, size: 64, color: Colors.grey[400])
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(delay: 200.ms),
              const SizedBox(height: 16),
              Text(
                'No moments computed yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Click "Compute Moments" to analyze your spending patterns.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _moments.length,
      itemBuilder: (context, index) {
        final moment = _moments[index];
        final habitId = moment['habit_id'] ?? '';
        final confidence = (moment['confidence'] ?? 0.0) as double;
        final value = (moment['value'] ?? 0.0) as double;
        final confidenceColor = _getConfidenceColor(confidence);
        
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: confidenceColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getMomentIcon(habitId),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moment['label'] ?? 'Moment',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: confidenceColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: confidenceColor.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${(confidence * 100).toStringAsFixed(0)}% confidence',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: confidenceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms),
              const SizedBox(height: 12),
              Text(
                moment['insight_text'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50 + 50).ms),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatMomentValue(habitId, value),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: PremiumTheme.goldPrimary,
                        ),
                  ),
                  Text(
                    habitId.replaceAll('_', ' '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50 + 100).ms),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(delay: (index * 50).ms);
      },
    );
  }

  String _getMomentIcon(String habitId) {
    if (habitId.contains('burn_rate') || habitId.contains('spend_to_income')) {
      return '📈';
    }
    if (habitId.contains('micro') || habitId.contains('cash')) {
      return 'ℹ️';
    }
    return '⚠️';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatMomentValue(String habitId, double value) {
    if (habitId.contains('ratio') || habitId.contains('share')) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    if (habitId.contains('count')) {
      return value.toStringAsFixed(0);
    }
    return '₹${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  Widget _buildNudgesTab() {
    if (_nudges.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.grey[400])
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(delay: 200.ms),
              const SizedBox(height: 16),
              Text(
                'No nudges delivered yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Click "Evaluate & Deliver Nudges" to generate personalized nudges based on your spending patterns.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ),
        )
            .animate()
            .fadeInSlideUp(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _nudges.length,
      itemBuilder: (context, index) {
        final nudge = _nudges[index];
        final title = nudge['title'] ?? nudge['title_template'] ?? 'Nudge';
        final body = nudge['body'] ?? nudge['body_template'] ?? '';
        final sentAt = nudge['sent_at'];
        
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('✨', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nudge['rule_name'] ?? 'Nudge',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (sentAt != null)
                    Text(
                      _formatDate(sentAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              )
                  .animate()
                  .fadeInSlideUp(delay: (index * 50).ms),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                )
                    .animate()
                    .fadeInSlideUp(delay: (index * 50 + 50).ms),
              ],
              if (nudge['cta_text'] != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Handle CTA
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PremiumTheme.goldPrimary,
                      side: BorderSide(
                        color: PremiumTheme.goldPrimary.withOpacity(0.5),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(nudge['cta_text'] ?? ''),
                  ),
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

