import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/providers/notification_provider.dart';
import 'package:ai/core/providers/theme_provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/features/interests/screens/interests.dart';
import 'package:ai/features/quiz/providers/quiz_provider.dart';
import 'package:ai/features/quiz/providers/sm2_quiz_provider.dart';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:ai/features/settings/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/navigation/navigation_all.dart';
import 'package:ai/features/auth/screens/login.dart';
import 'package:ai/features/auth/screens/register.dart';
import 'package:ai/features/placement_tests/screens/testlevel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initLocalNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => Sm2QuizProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
        ChangeNotifierProvider(create: (_) => WordProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: _AppLifecycleListener(
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AI VOCABGEN',
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const _AppRouter(),
          ),
        ),
      ),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _wasLoggedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _wasLoggedIn = auth.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (_wasLoggedIn && !auth.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<Sm2QuizProvider>().reset();
            context.read<QuizProvider>().reset();
            context.read<WordProvider>().clearSearch();
          });
        }
        _wasLoggedIn = auth.isLoggedIn;

        if (auth.isInitializing) return const _SplashScreen();

        if (!auth.isLoggedIn) return const _AuthFlow();

        if (!auth.isEmailVerified) return const SettingsScreen();

        if (auth.needsInterests) return const InterestsScreen();

        if (!auth.hasTakenTest) return const TestScreen();

        return const Navigation();
      },
    );
  }
}

class _AppLifecycleListener extends StatefulWidget {
  final Widget child;
  const _AppLifecycleListener({required this.child});

  @override
  State<_AppLifecycleListener> createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<_AppLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final notifier =
          Provider.of<NotificationProvider>(context, listen: false);
      notifier.sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  final _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          LoginScreen(controller: _pageController),
          SignUpScreen(controller: _pageController),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const LearningAppBar(
        title: 'AI VOCABGEN',
        subtitle: 'Preparing your learning space',
        icon: Icons.auto_stories_rounded,
      ),
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
