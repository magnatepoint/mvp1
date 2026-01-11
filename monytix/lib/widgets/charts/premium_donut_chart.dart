import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../glass_card.dart';
import '../../theme/premium_theme.dart';
import 'premium_pie_chart.dart';

class PremiumDonutChart extends StatefulWidget {
  final List<ChartData> data;
  final double size;
  final double holeRadius;
  final bool showLabels;
  final bool showLegend;
  final String? title;
  final String? subtitle;
  final Widget? centerWidget;

  const PremiumDonutChart({
    super.key,
    required this.data,
    this.size = 200,
    this.holeRadius = 0.6,
    this.showLabels = true,
    this.showLegend = true,
    this.title,
    this.subtitle,
    this.centerWidget,
  });

  @override
  State<PremiumDonutChart> createState() => _PremiumDonutChartState();
}

class _PremiumDonutChartState extends State<PremiumDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getTotal() {
    return widget.data.fold(0.0, (sum, item) => sum + item.value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _getTotal();
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
            const SizedBox(height: 20),
          ],
          Center(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = null;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: widget.size * widget.holeRadius,
                          sections: _buildSections(total),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 200.ms, begin: const Offset(0.8, 0.8)),
                  if (widget.centerWidget != null)
                    widget.centerWidget!
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 400.ms)
                        .scale(delay: 400.ms, begin: const Offset(0.5, 0.5)),
                ],
              ),
            ),
          ),
          if (widget.showLegend) ...[
            const SizedBox(height: 20),
            _buildLegend(context),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(double total) {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percentage = (item.value / total) * 100;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? widget.size * 0.35 : widget.size * 0.3;

      return PieChartSectionData(
        value: item.value * _controller.value,
        title: widget.showLabels && percentage > 5
            ? '${percentage.toStringAsFixed(0)}%'
            : '',
        color: item.color,
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(BuildContext context) {
    final total = _getTotal();
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final percentage = (item.value / total) * 100;
        final isTouched = index == _touchedIndex;

        return InkWell(
          onTap: () {
            setState(() {
              _touchedIndex = isTouched ? null : index;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTouched
                  ? item.color.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTouched ? item.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

