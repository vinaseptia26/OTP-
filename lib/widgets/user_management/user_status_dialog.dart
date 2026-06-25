// lib/widgets/user_management/user_status_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/user_helpers.dart';

class UserStatusDialog extends StatelessWidget {
  final String userName;
  final bool isActivating;

  const UserStatusDialog({
    super.key,
    required this.userName,
    required this.isActivating,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: UserHelpers.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActivating
                    ? UserHelpers.accentGreen.withOpacity(0.1)
                    : UserHelpers.accentOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActivating ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                color: isActivating ? UserHelpers.accentGreen : UserHelpers.accentOrange,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              isActivating ? 'Konfirmasi Aktivasi' : 'Konfirmasi Penonaktifan',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: UserHelpers.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              isActivating
                  ? 'Apakah Anda yakin ingin mengaktifkan akun "$userName"?\n\nPengguna akan dapat login dan mengakses sistem kembali.'
                  : 'Apakah Anda yakin ingin menonaktifkan akun "$userName"?\n\nPengguna tidak akan dapat login hingga akun diaktifkan kembali.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: UserHelpers.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                // Batal
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: UserHelpers.dividerColor),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: UserHelpers.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Konfirmasi
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActivating ? UserHelpers.accentGreen : UserHelpers.accentOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isActivating ? 'Ya, Aktifkan' : 'Ya, Nonaktifkan',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Static method to show dialog
  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required bool isActivating,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserStatusDialog(
        userName: userName,
        isActivating: isActivating,
      ),
    );
  }
}