import 'package:flutter/material.dart';
import '../glass_card.dart';

class ChartContainer extends StatelessWidget {
  final Widget chart;
  final String? title;
  final String? subtitle;
  final Widget? legend;

  const ChartContainer({
    super.key,
    required this.chart,
    this.title,
    this.subtitle,
    this.legend,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
            const SizedBox(height: 20),
          ],
          chart,
          if (legend != null) ...[
            const SizedBox(height: 16),
            legend!,
          ],
        ],
      ),
    );
  }
}

