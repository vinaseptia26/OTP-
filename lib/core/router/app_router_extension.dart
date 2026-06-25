// lib/core/routes/app_router_extension.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/services/faq_model_service.dart';

extension AppRouterExtension on BuildContext {
  // Auth Navigation
  void goToLogin() => go('/login');
  void goToRegister() => go('/register');
  void goToWelcome() => go('/welcome');

  // Dashboard Navigation (berdasarkan role)
  void goToDashboard(String role) {
    switch (role) {
      case 'superadmin':
        go('/superadmin-dashboard');
        break;
      case 'manager':
        go('/manager-dashboard');
        break;
      case 'pengawas':
        go('/pengawas-dashboard');
        break;
      case 'officer_safety':
        go('/officer-safety-dashboard');
        break;
      case 'mitra':
        go('/mitra-dashboard');
        break;
      default:
        go('/login');
    }
  }

  // FAQ Navigation
  void goToFAQ({bool isSuperAdmin = false}) {
    go('/faq', extra: {'isSuperAdmin': isSuperAdmin});
  }

  void goToFAQDetail({
    required FAQModel faqData,
    bool isSuperAdmin = false,
  }) {
    go('/faq/detail/${faqData.id}', extra: {
      'faqData': faqData,
      'isSuperAdmin': isSuperAdmin,
    });
  }

  void goToAddFAQ() => go('/faq/add');
  
  void goToEditFAQ(FAQModel faqData) {
    go('/faq/edit/${faqData.id}', extra: {'faqToEdit': faqData});
  }

  // Chat Navigation
  void goToChatList() => go('/chat');
  
  void goToChatRoom({
    required String chatRoomId,
    String? chatRoomName,
  }) {
    go('/chat/$chatRoomId', extra: {
      'chatRoomName': chatRoomName,
    });
  }

  // Manager Navigation
  void goToMemberDetail({
    required String memberId,
    Map<String, dynamic>? memberData,
  }) {
    go('/member-detail/$memberId', extra: {
      'member': memberData,
    });
  }

  void goToLocationMonitoring() => go('/location-monitoring');
  void goToOvertimeData() => go('/overtime-data');

  // SuperAdmin Navigation
  void goToUserManagement() => go('/user-management');
  void goToHelpDesk() => go('/help-desk-admin');
  void goToSettings() => go('/settings');
  void goToOvertimeRates() => go('/settings/overtime-rates');
  void goToReportsAudit() => go('/reports-audit');
  void goToSystemLogs() => go('/system-logs');
  void goToAdminApproval() => go('/admin/approval');

  // Pengawas Navigation
  void goToAjukanLembur() => go('/ajukan-lembur');
  void goToMyTeam() => go('/my-team');

  // Mitra Navigation
  void goToRiwayatAbsensi() => go('/riwayat-absensi');
  void goToJadwalLembur() => go('/jadwal-lembur');

  // Shared Navigation
  void goToProfile() => go('/profile');

  // Back Navigation
  void goBack() => pop();
}