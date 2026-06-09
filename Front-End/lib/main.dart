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
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) return const _SplashScreen();

        if (!auth.isLoggedIn) return const _AuthFlow();

        if (auth.needsInterests) return const InterestsScreen();

        if (!auth.hasTakenTest) return const TestScreen();

        return const Navigation();
      },
    );
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
