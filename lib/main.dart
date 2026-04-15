import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

// IMPORT SEMUA SCREEN
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

import '../dashboard/superadmin/superadmin_dashboard.dart';
import '../dashboard/superadmin/user_management.dart';
import '../dashboard/superadmin/help_desk_admin_screen.dart';
import '../dashboard/superadmin/settings/settings_screen.dart';
import '../dashboard/superadmin/settings/overtime_rates_screen.dart';
import '../dashboard/superadmin/overtime_history_screen.dart';
import '../dashboard/superadmin/laporan_audit_screen.dart';
import '../dashboard/superadmin/system_logs_screen.dart';

import '../dashboard/manager/manager_dashboard.dart';
import '../dashboard/manager/approval_lembur_screen.dart';
import '../dashboard/manager/analytics_menu_screen.dart';

import '../dashboard/pengawas/pengawas_dashboard.dart';

import '../dashboard/mitra/mitra_dashboard.dart';
import '/dashboard/mitra/absensi_screen.dart';
import '/dashboard/mitra/camera_absensi.dart';
import '/dashboard/mitra/jadwal_lembur_screen.dart';

import '/screens/profile_menu_screen.dart';

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
        '/': (context) => const WelcomeScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/mitra-dashboard': (context) => const MitraDashboard(),
        '/pengawas-dashboard': (context) => const PengawasDashboard(),
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/superadmin-dashboard': (context) => const SuperAdminDashboard(),
        '/user-management': (context) => const UserManagementScreen(),
        '/help-desk-admin': (context) => const HelpDeskAdminScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/overtime-rates': (context) => const OvertimeRatesScreen(),
        '/overtime-data': (context) => const OvertimeHistoryScreen(),
        '/mitra/absensi': (context) => const AbsensiHistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/jadwal-lembur-menu': (context) => const JadwalLemburMenu(),
        '/absensi': (context) => const CameraAbsensiScreen(),
        '/reports-audit': (context) => const ReportAuditPage(),
        '/system-logs': (context) => const SystemLogsScreen(),
      },
      
      // ✅ PERBAIKAN: Hanya untuk route yang TIDAK ADA di routes
      onGenerateRoute: (settings) {
        // Log route yang dicoba diakses (untuk debugging)
        debugPrint('Mencoba akses route: ${settings.name}');
        
        // Handle route dengan parameter (contoh)
        if (settings.name == '/lembur-detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          // TODO: Return LemburDetailScreen dengan parameter
          // return MaterialPageRoute(
          //   builder: (context) => LemburDetailScreen(lemburId: args?['id']),
          // );
        }
        
        // ⚠️ JANGAN return untuk route yang tidak dikenal!
        // Biarkan Flutter menampilkan error default
        return null;  // ← INI PENTING! Biarkan null untuk route yang tidak dikenal
      },
      
      // Atau bisa juga pakai onUnknownRoute untuk route yang benar-benar tidak dikenal
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Halaman ${settings.name} tidak ditemukan'),
            ),
          ),
        );
      },
    );
  }
}