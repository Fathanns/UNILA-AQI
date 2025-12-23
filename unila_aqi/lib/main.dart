import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/themes/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/room_provider.dart';
import 'presentation/providers/building_provider.dart';
import 'presentation/pages/auth/mode_selection_screen.dart';
import 'presentation/pages/dashboard/dashboard_screen.dart';
import 'core/services/storage_service.dart';

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
    return MaterialApp(
      title: 'UNILA Air Quality Index',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const ModeSelectionScreen(),
        '/dashboard': (context) => const DashboardScreen(isAdminMode: false),
        '/admin-dashboard': (context) => const DashboardScreen(isAdminMode: true),
      },
      // Enable smooth scrolling
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}