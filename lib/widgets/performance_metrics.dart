// lib/features/superadmin/widgets/performance_metrics.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_colors.dart';

class PerformanceMetrics extends StatefulWidget {
  const PerformanceMetrics({super.key});

  @override
  State<PerformanceMetrics> createState() => _PerformanceMetricsState();
}

class _PerformanceMetricsState extends State<PerformanceMetrics> {
  Map<String, dynamic> _metrics = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('health_check')
          .doc('current')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _metrics = {
            'responseTime': data['response_time'] ?? '245',
            'responseUnit': data['response_unit'] ?? 'ms',
            'responseTrend': data['response_trend'] ?? 12,
            'errorRate': data['error_rate'] ?? '0.3',
            'errorTrend': data['error_trend'] ?? 5,
            'reqPerMin': data['req_per_min'] ?? '1.2',
            'reqUnit': data['req_unit'] ?? 'k',
            'reqTrend': data['req_trend'] ?? 8,
          };
          _loading = false;
        });
      } else {
        // Fallback dari system_settings
        final settingsDoc = await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('performance')
            .get();

        if (settingsDoc.exists && mounted) {
          final data = settingsDoc.data()!;
          setState(() {
            _metrics = {
              'responseTime': data['response_time'] ?? '245',
              'responseUnit': 'ms',
              'responseTrend': data['response_trend'] ?? 12,
              'errorRate': data['error_rate'] ?? '0.3',
              'errorTrend': data['error_trend'] ?? 5,
              'reqPerMin': data['req_per_min'] ?? '1.2',
              'reqUnit': 'k',
              'reqTrend': data['req_trend'] ?? 8,
            };
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    final responseTime = _metrics['responseTime'] ?? '245';
    final responseUnit = _metrics['responseUnit'] ?? 'ms';
    final responseTrend = (_metrics['responseTrend'] as int?) ?? 12;
    final errorRate = _metrics['errorRate'] ?? '0.3';
    final errorTrend = (_metrics['errorTrend'] as int?) ?? 5;
    final reqPerMin = _metrics['reqPerMin'] ?? '1.2';
    final reqUnit = _metrics['reqUnit'] ?? 'k';
    final reqTrend = (_metrics['reqTrend'] as int?) ?? 8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text('Metrik Kinerja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetric(
                'Response Time',
                '$responseTime $responseUnit',
                responseTrend,
                responseTrend > 0,
              ),
              _buildMetric(
                'Error Rate',
                '$errorRate%',
                errorTrend,
                errorTrend <= 0,
              ),
              _buildMetric(
                'Req/min',
                '$reqPerMin$reqUnit',
                reqTrend,
                reqTrend > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, int trend, bool isPositive) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPositive
                  ? Colors.green.withAlpha(26)
                  : Colors.red.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  '$trend%',
                  style: TextStyle(
                    fontSize: 9,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
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