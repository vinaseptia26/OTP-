// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'core/router/app_router.dart';
import 'core/services/overtime_approval_service.dart';
import 'core/services/overtime_rate_service.dart';
import 'core/services/spkl_generator_service.dart';
import 'core/services/notification_service.dart';
import 'core/controllers/approval_controller.dart';

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
    final appRouter = AppRouter();

    return MultiProvider(
      providers: [
        // ============ FIREBASE SERVICES ============
        Provider<FirebaseAuth>(
          create: (_) => FirebaseAuth.instance,
        ),
        
        Provider<FirebaseFirestore>(
          create: (_) => FirebaseFirestore.instance,
        ),

        // ============ CORE SERVICES ============
        Provider<SpklGeneratorService>(
          create: (_) => SpklGeneratorService(),
        ),
        
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        
        Provider<OvertimeRateService>(
          create: (_) => OvertimeRateService(),
        ),

        // ============ OVERTIME APPROVAL SERVICE ============
        Provider<OvertimeApprovalService>(
          create: (context) => OvertimeApprovalService(
            firestore: context.read<FirebaseFirestore>(),
            auth: context.read<FirebaseAuth>(),
            spklGenerator: context.read<SpklGeneratorService>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),

        // ============ CONTROLLERS ============
        ChangeNotifierProvider<ApprovalController>(
          create: (context) => ApprovalController(
            auth: context.read<FirebaseAuth>(),
            firestore: context.read<FirebaseFirestore>(),
            approvalService: context.read<OvertimeApprovalService>(),
            rateService: context.read<OvertimeRateService>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Aplikasi OTP',
        debugShowCheckedModeBanner: false,

        routerConfig: appRouter.router,

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
          
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3C72),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E3C72),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}