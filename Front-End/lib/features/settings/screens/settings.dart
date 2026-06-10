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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai/core/models/interest.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/providers/notification_provider.dart';
import 'package:ai/core/providers/theme_provider.dart';
import 'package:ai/features/placement_tests/screens/testlevel.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';


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

  Future<void> _showVerifyEmailDialog(AuthProvider auth) async {
    final codeController = TextEditingController();
    final codeFormKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verify Email"),
        content: Form(
          key: codeFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                auth.userEmail ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (!codeFormKey.currentState!.validate()) return;
              final success = await auth.verifyEmail(
                auth.userEmail ?? '',
                codeController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, success);
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: ok == true,
      successMsg: 'Email verified ✓',
      failMsg: auth.errorMessage ?? 'Invalid code',
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

  Future<void> _showDeleteAccountDialog(AuthProvider auth) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action is permanent. Enter your password to confirm.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your current password';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await auth.deleteAccount(
                passwordController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, success);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    SettingsLogic.showSnack(
      context,
      ok: confirmed == true,
      successMsg: 'Account deleted ✓',
      failMsg: auth.errorMessage ?? 'Failed to delete account',
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
    if (val) {
      await NotificationProvider.showTestNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: "Settings",
        subtitle: "Manage your learning profile",
        icon: Icons.tune_rounded,
        metricLabel: "Level",
        metricValue: auth.userLevel ?? "A1",
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
            if (auth.isEmailVerified)
              SettingsTile(
                icon: Icons.verified,
                title: "Email Verification",
                subtitle: "Verified",
                trailing: Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.green,
                ),
              )
            else
              SettingsTile(
                icon: Icons.warning_amber,
                title: "Email Verification",
                subtitle: "Not verified",
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showVerifyEmailDialog(auth),
                  child: Text(
                    "Verify",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            SizedBox(height: 16),

            
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
              icon: Icons.delete_forever,
              title: "Delete Account",
              titleColor: AppColors.error,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textLight,
              ),
              onTap: () => _showDeleteAccountDialog(auth),
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
              onTap: () => LogoutHelper.showConfirmLogout(context, auth),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
