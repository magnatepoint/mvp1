import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'glass_card.dart';

class PremiumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final int index;

  const PremiumStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28)
                .animate()
                .fadeIn(duration: 300.ms, delay: (index * 100).ms)
                .scale(delay: (index * 100).ms),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (index * 100 + 50).ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (index * 100 + 100).ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 100).ms)
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOut);
  }
}

