import 'package:ai/features/quiz/screens/quizes.dart';
import 'package:ai/features/add_word/screens/add_word.dart';
import 'package:ai/features/home/screens/home.dart';
import 'package:ai/features/progress/screens/progress.dart';
import 'package:ai/features/settings/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:ai/core/theme/colors.dart';

class Navigation extends StatelessWidget {
  const Navigation({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PersistentTabController(initialIndex: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PersistentTabView(
        context,
        controller: controller,

        //  الشاشات
        screens: [
          HomeScreen(),
          QuizScreen(),
          AddWordScreen(),
          ProgressScreen(),
          SettingsScreen(),
        ],

        //  العناصر
        items: [
          PersistentBottomNavBarItem(
            icon: Icon(Icons.home),
            title: "Home",
            activeColorPrimary: AppColors.navActive,
            inactiveColorPrimary: AppColors.navInactive,
          ),
          PersistentBottomNavBarItem(
            icon: Icon(Icons.quiz),
            title: "Quiz",
            activeColorPrimary: AppColors.navActive,
            inactiveColorPrimary: AppColors.navInactive,
          ),
          PersistentBottomNavBarItem(
            icon: Icon(Icons.add),
            title: "Add",
            activeColorPrimary: AppColors.navActive,
            inactiveColorPrimary: AppColors.navInactive,
          ),
          PersistentBottomNavBarItem(
            icon: Icon(Icons.bar_chart),
            title: "Progress",
            activeColorPrimary: AppColors.navActive,
            inactiveColorPrimary: AppColors.navInactive,
          ),
          PersistentBottomNavBarItem(
            icon: Icon(Icons.settings),
            title: "Settings",
            activeColorPrimary: AppColors.navActive,
            inactiveColorPrimary: AppColors.navInactive,
          ),
        ],

        // 🎨 التصميم
        navBarStyle: NavBarStyle.style6,

        // ✨ تحسينات
        backgroundColor: AppColors.card,
        decoration: NavBarDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),

        navBarHeight: 65,
        padding: EdgeInsets.symmetric(vertical: 6),

        onItemSelected: (index) {
          controller.jumpToTab(index);
        },
      ),
    );
  }
}
