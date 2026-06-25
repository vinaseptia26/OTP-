// lib/widgets/ajukan_lembur/budget_breakdown_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class BudgetBreakdownSection extends StatelessWidget {
  final double totalJam;
  final int validMirasCount;
  final double biayaLemburPerMitra;
  final double totalBiayaLembur;
  final String Function(double) formatRupiah;

  const BudgetBreakdownSection({
    super.key,
    required this.totalJam,
    required this.validMirasCount,
    required this.biayaLemburPerMitra,
    required this.totalBiayaLembur,
    required this.formatRupiah,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Rincian Biaya Lembur',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF6A1B9A),
      children: [
        // Header info
        _buildHeaderInfo(),
        const SizedBox(height: 16),
        
        // Rate info
        _buildRateInfo(),
        const SizedBox(height: 16),
        
        // Biaya Lembur per Mitra
        _buildBudgetItem(
          icon: Icons.person_rounded,
          title: 'Biaya per Mitra',
          detail: '${totalJam.toStringAsFixed(1)} jam × tarif lembur',
          amount: formatRupiah(biayaLemburPerMitra),
          color: const Color(0xFF1976D2),
        ),
        const Divider(height: 24),
        
        // Total Biaya Lembur
        _buildBudgetItem(
          icon: Icons.people_rounded,
          title: 'Total Biaya Lembur',
          detail: '$validMirasCount mitra × ${formatRupiah(biayaLemburPerMitra)}',
          amount: formatRupiah(totalBiayaLembur),
          color: const Color(0xFF00897B),
          isTotal: true,
        ),
        const SizedBox(height: 16),
        
        // Grand Total
        _buildGrandTotal(),
        
        // Footer note
        const SizedBox(height: 12),
        _buildFooterNote(),
      ],
    );
  }

  // ==================== HEADER INFO ====================
  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6A1B9A).withValues(alpha: 0.05),
            const Color(0xFF6A1B9A).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Color(0xFF6A1B9A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perhitungan Biaya Lembur',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
                const SizedBox(height: 6),
                // 🔥 PERBAIKAN: Gunakan Wrap untuk menghindari overflow
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      icon: Icons.people_outline,
                      label: '$validMirasCount mitra',
                    ),
                    _buildInfoChip(
                      icon: Icons.timer_outlined,
                      label: '${totalJam.toStringAsFixed(1)} jam',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO CHIP ====================
  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6A1B9A)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6A1B9A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RATE INFO ====================
  Widget _buildRateInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Biaya lembur dihitung berdasarkan tarif per jam yang berlaku',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUDGET ITEM ====================
  Widget _buildBudgetItem({
    required IconData icon,
    required String title,
    required String detail,
    required String amount,
    required Color color,
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTotal ? color.withValues(alpha: 0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isTotal
            ? Border.all(color: color.withValues(alpha: 0.2), width: 1.5)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTotal ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, size: isTotal ? 20 : 18, color: color),
          ),
          const SizedBox(width: 10),
          // 🔥 PERBAIKAN: Gunakan Expanded + Flexible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                    fontSize: isTotal ? 14 : 13,
                    color: isTotal ? color : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 🔥 PERBAIKAN: Gunakan Flexible untuk amount
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isTotal ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: isTotal
                    ? Border.all(color: color.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTotal ? 16 : 14,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GRAND TOTAL ====================
  Widget _buildGrandTotal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔥 PERBAIKAN: Layout yang lebih aman untuk mobile
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: label
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL BIAYA LEMBUR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Info chips dalam Wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildTotalInfoChip(
                          icon: Icons.people_outline,
                          label: '$validMirasCount mitra',
                        ),
                        _buildTotalInfoChip(
                          icon: Icons.timer_outlined,
                          label: '${totalJam.toStringAsFixed(1)} jam',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right side: amount
              Expanded(
                flex: 2,
                child: Text(
                  formatRupiah(totalBiayaLembur),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Estimasi berdasarkan tarif yang berlaku',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FOOTER NOTE ====================
  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Perhitungan biaya lembur berdasarkan tarif per jam yang berlaku. '
              'Biaya final dapat disesuaikan setelah persetujuan.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}