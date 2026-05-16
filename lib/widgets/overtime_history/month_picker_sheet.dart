import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MonthPickerSheet {
  /// Menampilkan bottom sheet untuk memilih bulan
  static void show(
    BuildContext context, {
    required String selectedMonth,
    required ValueChanged<String> onMonthSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MonthPickerContent(
        selectedMonth: selectedMonth,
        onMonthSelected: onMonthSelected,
      ),
    );
  }
}

class _MonthPickerContent extends StatelessWidget {
  final String selectedMonth;
  final ValueChanged<String> onMonthSelected;

  const _MonthPickerContent({
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      color: Color(0xFF1976D2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pilih Bulan',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Quick select: Bulan ini
                  TextButton(
                    onPressed: () {
                      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
                      onMonthSelected(currentMonth);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Bulan Ini',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(height: 1, color: Colors.grey.shade200),
            ),

            const SizedBox(height: 8),

            // Month list
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                itemCount: 12, // 12 bulan ke belakang
                itemBuilder: (context, index) {
                  final date = DateTime(
                    DateTime.now().year,
                    DateTime.now().month - index,
                  );
                  final monthStr = DateFormat('yyyy-MM').format(date);
                  final monthDisplay = DateFormat('MMMM yyyy', 'id_ID').format(date);
                  final isSelected = selectedMonth == monthStr;
                  final isCurrentMonth = index == 0;

                  return _MonthItem(
                    monthStr: monthStr,
                    monthDisplay: monthDisplay,
                    isSelected: isSelected,
                    isCurrentMonth: isCurrentMonth,
                    onTap: () {
                      onMonthSelected(monthStr);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MonthItem extends StatelessWidget {
  final String monthStr;
  final String monthDisplay;
  final bool isSelected;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  const _MonthItem({
    required this.monthStr,
    required this.monthDisplay,
    required this.isSelected,
    required this.isCurrentMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF1976D2).withValues(alpha: 0.1) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFF1976D2) 
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Month icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF1976D2) 
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.date_range,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Month info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            monthDisplay,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? const Color(0xFF1976D2) 
                                  : Colors.black87,
                            ),
                          ),
                          if (isCurrentMonth) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sekarang',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthStr,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                if (isSelected)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}