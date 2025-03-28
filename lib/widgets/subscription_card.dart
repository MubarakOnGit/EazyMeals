import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionCard extends StatelessWidget {
  final bool isActive;
  final String? plan;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isPaused;
  final VoidCallback? onPauseToggle;
  final VoidCallback? onSubscribe;

  const SubscriptionCard({
    super.key,
    required this.isActive,
    this.plan,
    this.startDate,
    this.endDate,
    this.isPaused = false,
    this.onPauseToggle,
    this.onSubscribe,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRemainingDays() {
    if (endDate == null) return 'N/A';
    final now = DateTime.now();
    final difference = endDate!.difference(now);
    return '${difference.inDays} days';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isActive ? 'Active Subscription' : 'No Active Subscription',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
                if (isActive)
                  IconButton(
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: isPaused ? Colors.green : Colors.orange,
                    ),
                    onPressed: onPauseToggle,
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text('Plan: ${plan ?? 'N/A'}'),
              Text('Start Date: ${_formatDate(startDate)}'),
              Text('End Date: ${_formatDate(endDate)}'),
              Text('Remaining: ${_getRemainingDays()}'),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Subscribe now to get started!'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Subscribe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 