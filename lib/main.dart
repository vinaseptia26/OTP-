import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

// IMPORT SEMUA SCREEN
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import '/screens/profile_menu_screen.dart';

// SUPERADMIN
import '../dashboard/superadmin/superadmin_dashboard.dart';
import '../dashboard/superadmin/user_management.dart';
import '../dashboard/superadmin/help_desk_admin_screen.dart';
import '../dashboard/superadmin/settings/settings_screen.dart';
import '../dashboard/superadmin/settings/overtime_rates_screen.dart';
import '../dashboard/superadmin/overtime_history_screen.dart';
import '../dashboard/superadmin/laporan_audit_screen.dart';
import '../dashboard/superadmin/system_logs_screen.dart';
import '../dashboard/superadmin/admin_approval_screen.dart';

// MANAGER
import '../dashboard/manager/manager_dashboard.dart';
import '../dashboard/manager/approval_lembur_screen.dart';
import '../dashboard/manager/location_menu_screen.dart';
import '../dashboard/manager/member_detail_screen.dart';

// PENGAWAS
import '../dashboard/pengawas/pengawas_dashboard.dart';
import 'dashboard/pengawas/ajukan_lembur_screen.dart';
import '../dashboard/pengawas/my_team_screen.dart';
// MITRA
import '../dashboard/mitra/mitra_dashboard.dart';
import 'dashboard/mitra/absensi_history_screen.dart';
import '/dashboard/mitra/jadwal_lembur_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi OTP',
      debugShowCheckedModeBanner: false,

      // LOCALIZATION
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),

      // THEME
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: false,
      ),

      // ROUTES
      initialRoute: '/',
      routes: {
        // ========== AUTH ==========
        '/': (context) => const WelcomeScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        // ========== MITRA ==========
        '/mitra-dashboard': (context) => const MitraDashboard(),
        '/riwayat-absensi': (context) => const AbsensiHistoryScreen(),
        '/jadwal-lembur-menu': (context) => const JadwalLemburMenu(),

        // ========== PENGAWAS ==========
        '/pengawas-dashboard': (context) => const PengawasDashboard(),
        '/ajukan-lembur': (context) => const AjukanLemburPage(),

        // ========== MANAGER ==========
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/approval-lembur': (context) => const ApprovalLemburScreen(),
        '/overtime-history': (context) => const OvertimeHistoryScreen(), 
        '/member-detail': (context) => const MemberDetailScreen(),
        '/location-monitoring': (context) => const LocationMenuScreen(teamMembers: [], locations: [],), // ✅ Manager Location
        '/profile': (context) => const ProfileScreen(),

        // ========== SUPERADMIN ==========
        '/superadmin-dashboard': (context) => const SuperAdminDashboard(),
        '/user-management': (context) => const UserManagementScreen(),
        '/help-desk-admin': (context) => const HelpDeskAdminScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/overtime-rates': (context) => const OvertimeRatesScreen(),
        '/overtime-data': (context) => const OvertimeHistoryScreen(),
        '/reports-audit': (context) => const ReportAuditPage(),
        '/system-logs': (context) => const SystemLogsScreen(),
        '/admin/approval': (context) => const AdminApprovalScreen(),
        '/my-team': (context) => const MyTeamScreen(),
      },

      // onGenerateRoute untuk route dengan parameter atau dynamic
      onGenerateRoute: (settings) {
        debugPrint('Mencoba akses route: ${settings.name}');

        // Handle route dengan parameter (contoh)
        if (settings.name == '/lembur-detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          // TODO: Return LemburDetailScreen dengan parameter
          // return MaterialPageRoute(
          //   builder: (context) => LemburDetailScreen(lemburId: args?['id']),
          // );
        }

        return null;
      },

      // Route tidak dikenal
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
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
                    'Route "${settings.name}" tidak terdaftar',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}