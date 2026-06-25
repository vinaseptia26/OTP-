// FILE: lib/core/routes/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// AUTH
import '../../screens/welcome_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/profile_menu_screen.dart';

// SUPERADMIN
import '../../dashboard/superadmin/superadmin_dashboard.dart';
import '../../dashboard/superadmin/user_management.dart';
import '../../dashboard/superadmin/help_desk_admin_screen.dart';
import '../../dashboard/superadmin/settings/settings_screen.dart';
import '../../dashboard/superadmin/settings/overtime_rates_screen.dart';
import '../../dashboard/superadmin/settings/about_app_screen.dart';
import '../../dashboard/superadmin/laporan_screen.dart';
import '../../dashboard/superadmin/system_logs_screen.dart';
import '../../dashboard/superadmin/admin_approval_screen.dart';
import '../../dashboard/superadmin/master_pekerja_screen.dart';

// MANAGER
import '../../dashboard/manager/manager_dashboard.dart';
import '../../dashboard/manager/location_menu_screen.dart';
import '../../dashboard/manager/member_detail_screen.dart';
import '../../dashboard/manager/approval_lembur_screen.dart';

// PENGAWAS
import '../../dashboard/pengawas/pengawas_dashboard.dart';
import '../../dashboard/pengawas/ajukan_lembur_screen.dart';
import '../../screens/my_team/my_team_screen.dart';

// MITRA
import '../../dashboard/mitra/mitra_dashboard.dart';
import '../../dashboard/mitra/absensi_history_screen.dart';
import '../../dashboard/mitra/jadwal_lembur_screen.dart';
import '../../dashboard/mitra/absensi_page.dart';
import '../../dashboard/mitra/pendapatan_screen.dart';

// FAQ & CHAT
import '../../screens/faq/faq_screen.dart';
import '../../screens/faq/faq_detail_screen.dart';
import '../../screens/faq/add_faq_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/chat/chat_room_screen.dart';

// SHARED
import '../../screens/overtime_history_screen.dart';

// SERVICES
import '../services/auth_service.dart';
import '../services/faq_model_service.dart';

class AppRouter {
  final AuthService _authService = AuthService();
  final FAQChatService _faqChatService = FAQChatService();

  GoRouter get router => GoRouter(
        redirect: _guardAuth,

        errorBuilder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Halaman Tidak Ditemukan'),
            backgroundColor: Colors.red,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Route "${state.uri}" tidak terdaftar',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),

        routes: [
          // ========== PUBLIC ROUTES ==========
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
          ),

          // ========== SUPERADMIN ROUTES ==========
          GoRoute(
            path: '/superadmin-dashboard',
            builder: (context, state) => const SuperAdminDashboard(),
          ),
          GoRoute(
            path: '/user-management',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/help-desk-admin',
            builder: (context, state) => const HelpDeskAdminScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/overtime-rates',
            builder: (context, state) => const OvertimeRatesScreen(),
          ),
          GoRoute(
            path: '/settings/about-app',
            builder: (context, state) => const AboutAppScreen(),
          ),
          // lib/routes/app_router.dart

          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) {
              // ✅ Ambil data dari state.extra
              final extra = state.extra as Map<String, dynamic>?;
              final userRole = extra?['userRole'] as String? ?? '';
              final userFungsi = extra?['userFungsi'] as String?;
              final userId = extra?['userId'] as String?;
              
              return ReportPage(
                userRole: userRole,
                userFungsi: userFungsi,
                userId: userId,
              );
            },
          ),
          GoRoute(
            path: '/system-logs',
            builder: (context, state) => const SystemLogsScreen(),
          ),
          GoRoute(
            path: '/admin/approval',
            builder: (context, state) => const ApprovalLemburScreen(),
          ),
          GoRoute(
            path: '/approval',
            builder: (context, state) => const ManagerApprovalLemburScreen(),
          ),
          GoRoute(
            path: '/superadmin/master-pekerja',
            builder: (context, state) => const MasterPekerjaScreen(),
          ),
          GoRoute(
            path: '/income',
            builder: (context, state) => const PendapatanScreen(),
          ),

          // ========== FAQ ROUTES ==========
          GoRoute(
            path: '/faq',
            builder: (context, state) {
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final isSuperAdmin = extra?['isSuperAdmin'] ?? false;
              return FAQScreen(isSuperAdmin: isSuperAdmin);
            },
          ),
          GoRoute(
            path: '/faq/detail/:faqId',
            builder: (context, state) {
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final faqData = extra?['faqData'] as FAQModel?;
              final isSuperAdmin = extra?['isSuperAdmin'] ?? false;

              if (faqData == null) {
                return const Scaffold(
                  body: Center(child: Text('FAQ tidak ditemukan')),
                );
              }

              return FAQDetailScreen(
                faqData: faqData,
                isSuperAdmin: isSuperAdmin,
                faqService: _faqChatService.faqService,
                chatService: _faqChatService.chatService,
              );
            },
          ),
          GoRoute(
            path: '/faq/add',
            builder: (context, state) {
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final faqToEdit = extra?['faqToEdit'] as FAQModel?;
              return AddFAQScreen(
                faqService: _faqChatService.faqService,
                faqToEdit: faqToEdit,
              );
            },
          ),
          GoRoute(
            path: '/faq/edit/:faqId',
            builder: (context, state) {
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final faqToEdit = extra?['faqToEdit'] as FAQModel?;
              return AddFAQScreen(
                faqService: _faqChatService.faqService,
                faqToEdit: faqToEdit,
              );
            },
          ),

          // ========== CHAT ROUTES ==========
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/chat/:chatRoomId',
            builder: (context, state) {
              final chatRoomId = state.pathParameters['chatRoomId'] ?? '';
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final chatRoomName = extra?['chatRoomName'] as String?;
              
              if (chatRoomId.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Chat Room tidak ditemukan')),
                );
              }

              return ChatRoomScreen(
                chatRoomId: chatRoomId,
                chatRoomName: chatRoomName,
              );
            },
          ),

          // ========== MANAGER ROUTES ==========
          GoRoute(
            path: '/manager-dashboard',
            builder: (context, state) => const ManagerDashboard(),
          ),
          GoRoute(
            path: '/overtime-data',
            builder: (context, state) => const OvertimeHistoryScreen(),
          ),
          GoRoute(
            path: '/location-monitoring',
            builder: (context, state) {
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              final userRole = extra?['userRole'] as String? ?? 'manager';
              return LocationMenuScreen(userRole: userRole);
            },
          ),
          GoRoute(
            path: '/member-detail/:memberId',
            builder: (context, state) {
              final memberId = state.pathParameters['memberId'] ?? '';
              // ✅ PERBAIKAN: Cast state.extra ke Map<String, dynamic>
              final extra = state.extra as Map<String, dynamic>?;
              return MemberDetailScreen(
                memberId: memberId,
                memberData: extra?['member'],
              );
            },
          ),

          // ========== PENGAWAS ROUTES ==========
          GoRoute(
            path: '/pengawas-dashboard',
            builder: (context, state) => const PengawasDashboard(),
          ),
          GoRoute(
            path: '/ajukan-lembur',
            builder: (context, state) => const AjukanLemburPage(),
          ),
          GoRoute(
            path: '/my-team',
            builder: (context, state) => const MyTeamScreen(),
          ),

          // ========== MITRA ROUTES ==========
          GoRoute(
            path: '/mitra-dashboard',
            builder: (context, state) => const MitraDashboard(),
          ),
          GoRoute(
            path: '/riwayat-absensi',
            builder: (context, state) => const AbsensiHistoryScreen(),
          ),
          GoRoute(
            path: '/jadwal-lembur',
            builder: (context, state) => const JadwalLemburScreen(),
          ),
          GoRoute(
            path: '/mitra-absensi',
            name: 'mitra-absensi',
            builder: (context, state) => const AbsensiPage(),
          ),

          // ========== SHARED ROUTES ==========
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

  Future<String?> _guardAuth(
      BuildContext context, GoRouterState state) async {
    final currentRoute = state.uri.toString();
    
    final cleanRoute = currentRoute.endsWith('/') && currentRoute != '/'
        ? currentRoute.substring(0, currentRoute.length - 1)
        : currentRoute;

    const publicRoutes = [
      '/',
      '/welcome',
      '/login',
      '/register',
    ];

    if (publicRoutes.contains(cleanRoute)) {
      if (_authService.isLoggedIn) {
        final role = await _authService.getUserRole();
        if (role != null) {
          return _authService.getDashboardPath(role);
        }
      }
      return null;
    }

    if (!_authService.isLoggedIn) {
      return '/login';
    }

    final validationResult = await _authService.validateAccess();
    if (validationResult != null) {
      return validationResult;
    }

    final role = await _authService.getUserRole();

    if (role != null) {
      final routeRoleMap = {
        '/superadmin': 'superadmin',
        '/manager': 'manager',
        '/pengawas': 'pengawas',
        '/officer-safety': 'officer_safety',
        '/mitra': 'mitra',
      };

      for (final entry in routeRoleMap.entries) {
        if (cleanRoute.startsWith(entry.key) && role != entry.value) {
          return _authService.getDashboardPath(role);
        }
      }

      const adminOnlyRoutes = [
        '/user-management',
        '/help-desk-admin',
        '/settings',
        '/settings/overtime-rates',
        '/reports-audit',
        '/system-logs',
        '/admin/approval',
        '/faq/add',
        '/faq/edit',
      ];

      if (adminOnlyRoutes.any((route) => cleanRoute.startsWith(route)) &&
          !['superadmin', 'manager'].contains(role)) {
        return _authService.getDashboardPath(role);
      }

      const superAdminOnlyRoutes = [
        '/settings',
        '/settings/overtime-rates',
        '/system-logs',
      ];

      if (superAdminOnlyRoutes.contains(cleanRoute) && role != 'superadmin') {
        return _authService.getDashboardPath(role);
      }

      const sharedRoutes = [
        '/profile',
        '/faq',
        '/chat',
        '/overtime-data',
        '/location-monitoring',
      ];

      if (sharedRoutes.any((route) => cleanRoute.startsWith(route))) {
        return null;
      }

      if (cleanRoute.startsWith('/mitra-absensi') && role != 'mitra') {
        return _authService.getDashboardPath(role);
      }
    }

    return null;
  }
}