import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/console_screen.dart';
import 'screens/spendsense_screen.dart';
import 'screens/goalcompass_screen.dart';
import 'screens/budgetpilot_screen.dart';
import 'screens/moneymoments_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/premium_theme.dart';
import 'utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  
  runApp(const MonytixApp());
}

class MonytixApp extends StatelessWidget {
  const MonytixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: PlatformUtils.isIOS
          ? CupertinoApp(
              title: 'Monytix',
              debugShowCheckedModeBanner: false,
              theme: CupertinoThemeData(
                primaryColor: PremiumTheme.goldPrimary,
                brightness: Brightness.light,
              ),
              home: const AuthWrapper(),
              routes: {
                '/settings': (context) => const SettingsScreen(),
              },
            )
          : MaterialApp(
              title: 'Monytix',
              debugShowCheckedModeBanner: false,
              theme: PremiumTheme.getLightTheme(),
              darkTheme: PremiumTheme.getDarkTheme(),
              themeMode: ThemeMode.system,
              home: const AuthWrapper(),
              routes: {
                '/settings': (context) => const SettingsScreen(),
              },
            ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ConsoleScreen(),
    const SpendSenseScreen(),
    const GoalCompassScreen(),
    const BudgetPilotScreen(),
    const MoneyMomentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.black.withOpacity(0.8),
          activeColor: PremiumTheme.goldPrimary,
          inactiveColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'Console',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.doc_text),
              activeIcon: Icon(CupertinoIcons.doc_text_fill),
              label: 'SpendSense',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.compass),
              activeIcon: Icon(CupertinoIcons.compass_fill),
              label: 'GoalCompass',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.creditcard),
              activeIcon: Icon(CupertinoIcons.creditcard_fill),
              label: 'BudgetPilot',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              activeIcon: Icon(CupertinoIcons.chart_bar_fill),
              label: 'MoneyMoments',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(
            builder: (context) => _screens[index],
          );
        },
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          indicatorColor: PremiumTheme.goldPrimary.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'SpendSense',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'GoalCompass',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'BudgetPilot',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'MoneyMoments',
            ),
          ],
        ),
      ),
    );
  }
}

// Auth wrapper to show login screen if not authenticated
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    return const MainNavigationScreen();
  }
}
