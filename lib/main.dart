import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme.dart';
import 'state/app_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diagnose_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize AppState
  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const NetPulseApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

class NetPulseApp extends StatelessWidget {
  const NetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    DiagnoseScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch AppState for connectivity changes
    final state = context.watch<AppState>();
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering_rounded,
                      color: AppColors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'NetPulse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: state.connectionType != 'None' 
                                ? AppColors.teal 
                                : AppColors.danger,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (state.connectionType != 'None' 
                                        ? AppColors.teal 
                                        : AppColors.danger)
                                    .withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.connectionType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: state.connectionType != 'None' 
                                ? AppColors.teal 
                                : AppColors.danger,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Screen content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.speed_rounded,
                  label: 'Speed',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.troubleshoot_rounded,
                  label: 'Diagnostics',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'History',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.teal.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.teal : AppColors.muted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.teal : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
