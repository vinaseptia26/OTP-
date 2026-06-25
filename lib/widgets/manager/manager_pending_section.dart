// lib/widgets/manager/manager_pending_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagerPendingSection extends StatelessWidget {
  final List<Map<String, dynamic>> pendingList;
  final String Function(String) getTimeAgo;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>) onReject;

  const ManagerPendingSection({
    super.key,
    required this.pendingList,
    required this.getTimeAgo,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.check_circle, size: 40, color: Colors.green[300]),
                  const SizedBox(height: 8),
                  const Text('Tidak ada pengajuan pending', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            )
          else
            ...pendingList.take(5).map((lembur) => _buildPendingItem(context, lembur)),
          if (pendingList.length > 5)
            Center(
              child: TextButton(
                onPressed: () => context.push('/approval-lembur'),
                child: Text('Lihat ${pendingList.length - 5} lainnya...', style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingItem(BuildContext context, Map<String, dynamic> lembur) {
    final primaryColor = const Color(0xFF1E3C72);

    // Konversi Timestamp ke String
    String createdAtString = '';
    final createdAt = lembur['created_at'];
    if (createdAt is Timestamp) {
      createdAtString = createdAt.toDate().toIso8601String();
    } else if (createdAt is String) {
      createdAtString = createdAt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withAlpha(30)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.work_history, color: primaryColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lembur['pengawas_nama'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${(lembur['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              if (createdAtString.isNotEmpty)
                Text(getTimeAgo(createdAtString),
                    style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onApprove(lembur),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onReject(lembur),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}