// lib/widgets/approval/risk_checklist_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiskChecklistDialog extends StatefulWidget {
  final Function(String notes) onApprove;

  const RiskChecklistDialog({
    super.key,
    required this.onApprove,
  });

  @override
  State<RiskChecklistDialog> createState() => _RiskChecklistDialogState();
}

class _RiskChecklistDialogState extends State<RiskChecklistDialog> {
  // 🔥 Static constants
  static const Color _primaryColor = Color(0xFF9C27B0);
  
  // 🔥 Checklist items (static, never changes)
  static const List<_ChecklistItem> _checklistItems = [
    _ChecklistItem(
      key: 'apd',
      label: 'APD Lengkap & Sesuai Standar',
      icon: Icons.health_and_safety,
    ),
    _ChecklistItem(
      key: 'izin',
      label: 'Izin Kerja Tersedia',
      icon: Icons.assignment_turned_in,
    ),
    _ChecklistItem(
      key: 'prosedur',
      label: 'Prosedur Safety Terpenuhi',
      icon: Icons.verified_user,
    ),
    _ChecklistItem(
      key: 'tim',
      label: 'Tim Tanggap Darurat Siap',
      icon: Icons.emergency,
    ),
    _ChecklistItem(
      key: 'alat',
      label: 'Alat Pemadam & P3K Tersedia',
      icon: Icons.fire_extinguisher,
    ),
    _ChecklistItem(
      key: 'briefing',
      label: 'Safety Briefing Dilakukan',
      icon: Icons.campaign,
    ),
  ];

  final Map<String, bool> _checklist = {};
  final TextEditingController _notesController = TextEditingController();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    // Initialize all checklist to false
    for (final item in _checklistItems) {
      _checklist[item.key] = false;
    }
  }

  bool get _allChecked => _checklist.values.every((v) => v);
  int get _checkedCount => _checklist.values.where((v) => v).length;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _buildHeader(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner
            _buildWarningBanner(),
            const SizedBox(height: 16),
            
            // Progress Indicator
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            
            // Checklist Title
            Row(
              children: [
                const Icon(Icons.checklist_rounded, size: 20, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Checklist Kelayakan K3',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                // Select All / Clear All
                _buildQuickAction(),
              ],
            ),
            const SizedBox(height: 8),
            
            // Checklist Items
            ..._checklistItems.map((item) => _buildChecklistItem(item)),
            
            const SizedBox(height: 16),
            
            // Divider
            const Divider(),
            const SizedBox(height: 8),
            
            // Notes Field
            Text(
              'Catatan Safety',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            _buildNotesField(),
            
            // Error Message
            if (_showError) ...[
              const SizedBox(height: 8),
              _buildErrorMessage(),
            ],
          ],
        ),
      ),
      actions: _buildActions(),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  // ============== HEADER ==============
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryColor, Color(0xFF6A1B9A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.health_and_safety, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Approve HSSE',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Verifikasi K3 sebelum approval',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        // Close button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
            ),
          ),
        ),
      ],
    );
  }

  // ============== WARNING BANNER ==============
  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pastikan seluruh aspek K3 telah dipenuhi sebelum menyetujui pekerjaan ini',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== PROGRESS INDICATOR ==============
  Widget _buildProgressIndicator() {
    final progress = _checklistItems.isEmpty ? 0.0 : _checkedCount / _checklistItems.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Progress: $_checkedCount/${_checklistItems.length} item',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _allChecked ? Colors.green : _primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _allChecked ? Colors.green : _primaryColor,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ============== QUICK ACTION ==============
  Widget _buildQuickAction() {
    if (_allChecked) {
      return TextButton.icon(
        onPressed: () {
          setState(() {
            for (final key in _checklist.keys) {
              _checklist[key] = false;
            }
            _showError = false;
          });
        },
        icon: const Icon(Icons.clear_all, size: 14),
        label: Text(
          'Clear',
          style: GoogleFonts.poppins(fontSize: 10),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[600],
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    
    return TextButton.icon(
      onPressed: () {
        setState(() {
          for (final key in _checklist.keys) {
            _checklist[key] = true;
          }
          _showError = false;
        });
      },
      icon: const Icon(Icons.done_all, size: 14),
      label: Text(
        'All',
        style: GoogleFonts.poppins(fontSize: 10),
      ),
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ============== CHECKLIST ITEM ==============
  Widget _buildChecklistItem(_ChecklistItem item) {
    final isChecked = _checklist[item.key] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isChecked ? _primaryColor.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isChecked
            ? Border.all(color: _primaryColor.withValues(alpha: 0.2))
            : null,
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (value) {
          setState(() {
            _checklist[item.key] = value ?? false;
            if (_allChecked) _showError = false;
          });
        },
        title: Row(
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isChecked ? _primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isChecked
                      ? const Color(0xFF1E293B)
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        activeColor: _primaryColor,
        checkColor: Colors.white,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ============== NOTES FIELD ==============
  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: GoogleFonts.poppins(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Tambahan catatan terkait K3 (opsional)...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // ============== ERROR MESSAGE ==============
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Harap checklist semua item K3 sebelum menyetujui',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== ACTION BUTTONS ==============
  List<Widget> _buildActions() {
    return [
      // Cancel Button
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[600],
          side: BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Batal',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      const SizedBox(width: 10),
      
      // Approve Button
      ElevatedButton.icon(
        onPressed: _allChecked
            ? () {
                final notes = _notesController.text.trim();
                final message = notes.isEmpty
                    ? 'Disetujui HSSE - Semua checklist K3 terpenuhi'
                    : 'Disetujui HSSE: $notes';
                widget.onApprove(message);
              }
            : () => setState(() => _showError = true),
        icon: const Icon(Icons.verified_user, size: 18),
        label: Text(
          'Setujui K3',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _allChecked ? Colors.green : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: _allChecked ? 2 : 0,
        ),
      ),
    ];
  }
}

// 🔥 Helper class untuk checklist items
class _ChecklistItem {
  final String key;
  final String label;
  final IconData icon;

  const _ChecklistItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}