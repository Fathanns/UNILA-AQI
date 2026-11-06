import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:unila_aqi/presentation/pages/admin/building_management.dart';
import 'package:unila_aqi/presentation/pages/admin/iot_management.dart';
import 'package:unila_aqi/presentation/pages/admin/room_management.dart';
import 'core/themes/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/room_provider.dart';
import 'presentation/providers/building_provider.dart';
import 'presentation/pages/auth/mode_selection_screen.dart';
import 'presentation/pages/dashboard/dashboard_screen.dart';
import 'core/services/storage_service.dart';
import 'presentation/pages/admin/profile_management.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await StorageService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => BuildingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize socket connection when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      // FIXED: catchError agar rejection dari initSocket tidak unhandled.
      roomProvider.initSocket().catchError((e) {
        debugPrint('❌ initSocket error: $e');
      });
    });

    return MaterialApp(
      title: 'UNILA Air Quality Index',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',

      // ✅ Localization: dukung Bahasa Indonesia
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
        Locale('en', 'US'), // Fallback (opsional)
      ],
      locale: const Locale('id', 'ID'), // Default seluruh app ke Indonesia

      routes: {
        '/': (context) => const ModeSelectionScreen(),
        '/dashboard': (context) => const DashboardScreen(isAdminMode: false),
        '/admin-dashboard': (context) => const DashboardScreen(isAdminMode: true),
        '/admin/buildings': (context) => const BuildingManagementScreen(),
        '/admin/rooms': (context) => const RoomManagementScreen(),
        '/admin/iot-devices': (context) => const IoTManagementScreen(),
        '/admin/profile': (context) => const ProfileManagementScreen(),
      },
      // Enable smooth scrolling
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}