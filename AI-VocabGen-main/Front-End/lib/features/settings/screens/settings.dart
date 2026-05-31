import 'package:ai/features/interests/widgets/interests_sheet.dart';
import 'package:ai/features/auth/screens/logout.dart';
import 'package:ai/features/settings/logic/settings_logic.dart';
import 'package:ai/features/settings/widgets/avatar_picker_dialog.dart';
import 'package:ai/features/settings/widgets/change_email_dialog.dart';
import 'package:ai/features/settings/widgets/change_name_dialog.dart';
import 'package:ai/features/settings/widgets/change_password_dialog.dart';
import 'package:ai/features/settings/widgets/profile_header.dart';
import 'package:ai/features/settings/widgets/section_label.dart';
import 'package:ai/features/settings/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai/core/models/interest.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/providers/theme_provider.dart';
import 'package:ai/features/placement_tests/screens/testlevel.dart';
import 'package:ai/core/theme/colors.dart';

// ─── إعداد الإشعارات ─────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _notifications.initialize(settings);
}

Future<void> showTestNotification() async {
  const android = AndroidNotificationDetails(
    'main_channel',
    'Main Notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  const ios = DarwinNotificationDetails();
  const details = NotificationDetails(android: android, iOS: ios);
  await _notifications.show(
    0,
    'WordUp 📚',
    'Time to practice your vocabulary!',
    details,
  );
}

// ─── SettingsScreen ───────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _isSavingLevel = false;
  bool _isSavingInterests = false;
  int _selectedAvatarIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedAvatarIndex = prefs.getInt('avatarIndex') ?? 0;
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      });
    }
  }

  void _showAvatarPicker() {
    showDialog(
      context: context,
      builder: (_) => AvatarPickerDialog(
        currentIndex: _selectedAvatarIndex,
        onSelect: (i) async {
          setState(() => _selectedAvatarIndex = i);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('avatarIndex', i);
        },
      ),
    );
  }

  Future<void> _showChangeNameDialog(AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNameDialog(
        currentName: auth.userName,
        onSave: (name) => auth.updateName(name),
      ),
    );
    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: ok == true,
      successMsg: 'Name updated ✓',
      failMsg: 'Failed to update name',
    );
  }

  Future<void> _showChangeEmailDialog(AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeEmailDialog(
        currentEmail: auth.userEmail,
        onSave: (email) => auth.updateEmail(email),
      ),
    );
    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: ok == true,
      successMsg: 'Email updated ✓',
      failMsg: 'Failed to update email',
    );
  }

  Future<void> _showChangePasswordDialog(AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ChangePasswordDialog(
        onSave: ({required currentPassword, required newPassword}) =>
            auth.updatePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
            ),
      ),
    );
    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: ok == true,
      successMsg: 'Password updated ✓',
      failMsg: 'Failed to update password',
    );
  }

  Future<void> _onRetakeLevelTest(AuthProvider auth) async {
    final String? resultLevel = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => TestScreen(isRetake: true)),
    );

    if (resultLevel != null) {
      if (!mounted) return;
      setState(() => _isSavingLevel = true);
      final ok = await auth.updateLevel(resultLevel);
      if (!mounted) return;
      setState(() => _isSavingLevel = false);
      SettingsLogic.showSnack(
        context,
        ok: ok,
        successMsg: 'Level updated to $resultLevel ✓',
        failMsg: 'Failed to update level',
      );
    }
  }

  Future<void> _showInterestsSheet(AuthProvider auth) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InterestsSheet(
        currentSelected: List<InterestModel>.from(auth.userInterestModels),
        onSave: (selected) async {
          setState(() => _isSavingInterests = true);
          final result = await auth.updateInterestsModels(selected);
          if (mounted) setState(() => _isSavingInterests = false);
          return result;
        },
      ),
    );
    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: ok == true,
      successMsg: 'Interests saved ✓',
      failMsg: 'Failed to save interests',
    );
  }

  Future<void> _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', val);
    if (val) await showTestNotification();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              userName: auth.userName,
              userEmail: auth.userEmail,
              userLevel: auth.userLevel,
              selectedAvatarIndex: _selectedAvatarIndex,
              onPickAvatar: _showAvatarPicker,
            ),
            SizedBox(height: 28),

            // ─── Account Info ─────────────────────────────────
            SectionLabel(label: "ACCOUNT INFO"),
            SettingsTile(
              icon: Icons.person_outline,
              title: "Name",
              subtitle: auth.userName ?? '—',
              trailing: Icon(Icons.edit, size: 16, color: AppColors.textLight),
              onTap: () => _showChangeNameDialog(auth),
            ),
            SettingsTile(
              icon: Icons.email_outlined,
              title: "Email",
              subtitle: auth.userEmail ?? '—',
              trailing: Icon(Icons.edit, size: 16, color: AppColors.textLight),
              onTap: () => _showChangeEmailDialog(auth),
            ),
            SizedBox(height: 16),

            // ─── Learning ─────────────────────────────────────
            SectionLabel(label: "LEARNING"),
            SettingsTile(
              icon: Icons.assignment_turned_in,
              title: "My Level",
              subtitle: auth.userLevel != null
                  ? "Current: ${auth.userLevel}"
                  : "Not set yet",
              trailing: _isSavingLevel
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => _onRetakeLevelTest(auth),
                      child: Text(
                        "Retake Test",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            SettingsTile(
              icon: Icons.interests,
              title: "My Interests",
              subtitle: auth.userInterestModels.isEmpty
                  ? "None selected"
                  : auth.userInterestModels.map((m) => m.label).join(', '),
              trailing: _isSavingInterests
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textLight,
                    ),
              onTap: () => _showInterestsSheet(auth),
            ),
            SizedBox(height: 16),

            // ─── Preferences ──────────────────────────────────
            SectionLabel(label: "PREFERENCES"),
            SettingsTile(
              icon: Icons.notifications,
              title: "Notifications",
              subtitle: _notificationsEnabled ? "Enabled" : "Disabled",
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: AppColors.primary,
                onChanged: _toggleNotifications,
              ),
            ),
            SettingsTile(
              icon: Icons.dark_mode,
              title: "Dark Mode",
              subtitle: themeProvider.isDarkMode ? "On" : "Off",
              trailing: Switch(
                value: themeProvider.isDarkMode,
                activeColor: AppColors.primary,
                onChanged: themeProvider.toggleDarkMode,
              ),
            ),
            SizedBox(height: 16),

            // ─── Security ─────────────────────────────────────
            SectionLabel(label: "SECURITY"),
            SettingsTile(
              icon: Icons.lock_outline,
              title: "Change Password",
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textLight,
              ),
              onTap: () => _showChangePasswordDialog(auth),
            ),
            SettingsTile(
              icon: Icons.logout,
              title: "Log Out",
              titleColor: AppColors.error,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textLight,
              ),
              // ✅ LogoutHelper مباشرة — بدون _confirmLogout
              onTap: () => LogoutHelper.showConfirmLogout(context, auth),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
