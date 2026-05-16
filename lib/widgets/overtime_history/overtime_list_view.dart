import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import 'overtime_card.dart';

class OvertimeListView extends StatelessWidget {
  final OvertimeHistoryService historyService;
  final OvertimeRateService rateService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String? userName;
  final String selectedBulan;
  final String selectedStatus;

  const OvertimeListView({
    super.key,
    required this.historyService,
    required this.rateService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    this.userName,
    required this.selectedBulan,
    required this.selectedStatus,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeHistory>>(
      stream: historyService.getOvertimeHistoryStream(
        userRole: userRole,
        userFungsi: userFungsi,
        userId: userId,
        bulan: selectedBulan,
        statusFilter: selectedStatus,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat data',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada data',
                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                if (userRole == 'pengawas')
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/ajukan-lembur'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajukan Lembur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) => OvertimeCard(
            item: items[index],
            rateService: rateService,
            userId: userId,
            userName: userName,
            userRole: userRole,
          ),
        );
      },
    );
  }
}