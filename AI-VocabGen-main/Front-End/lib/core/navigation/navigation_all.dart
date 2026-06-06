import 'package:ai/core/providers/theme_provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/features/add_word/screens/add_word.dart';
import 'package:ai/features/home/screens/home.dart';
import 'package:ai/features/progress/screens/progress.dart';
import 'package:ai/features/quiz/screens/quizes.dart';
import 'package:ai/features/settings/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:provider/provider.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  late final PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final navBackground = AppColors.card;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PersistentTabView(
        context,
        key: ValueKey('bottom-nav-$isDarkMode'),
        controller: _controller,
        screens: const [
          HomeScreen(),
          QuizScreen(),
          AddWordScreen(),
          ProgressScreen(),
          SettingsScreen(),
        ],
        items: [
          _item(Icons.home, 'Home'),
          _item(Icons.quiz, 'Quiz'),
          _item(Icons.add, 'Add'),
          _item(Icons.bar_chart, 'Progress'),
          _item(Icons.settings, 'Settings'),
        ],
        navBarStyle: NavBarStyle.style6,
        backgroundColor: navBackground,
        decoration: NavBarDecoration(
          colorBehindNavBar: navBackground,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        navBarHeight: 65,
        padding: const EdgeInsets.symmetric(vertical: 6),
        onItemSelected: _controller.jumpToTab,
      ),
    );
  }

  PersistentBottomNavBarItem _item(IconData icon, String title) {
    return PersistentBottomNavBarItem(
      icon: Icon(icon),
      title: title,
      activeColorPrimary: AppColors.navActive,
      inactiveColorPrimary: AppColors.navInactive,
    );
  }
}
