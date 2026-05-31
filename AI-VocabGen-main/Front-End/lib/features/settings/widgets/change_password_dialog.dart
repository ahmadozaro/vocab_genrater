import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class ChangePasswordDialog extends StatefulWidget {
  final Future<bool> Function({
    required String currentPassword,
    required String newPassword,
  })
  onSave;

  const ChangePasswordDialog({super.key, required this.onSave});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "Change Password",
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PassField(
            controller: _currentCtrl,
            label: "Current Password",
            obscure: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          SizedBox(height: 12),
          _PassField(
            controller: _newCtrl,
            label: "New Password",
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          SizedBox(height: 12),
          _PassField(
            controller: _confirmCtrl,
            label: "Confirm New Password",
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          if (_error != null) ...[
            SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: AppColors.textLight)),
        ),
        _loading
            ? Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (_newCtrl.text != _confirmCtrl.text) {
                    setState(() => _error = "Passwords don't match");
                    return;
                  }
                  if (_newCtrl.text.length < 6) {
                    setState(
                      () => _error = "Password must be at least 6 characters",
                    );
                    return;
                  }
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  final ok = await widget.onSave(
                    currentPassword: _currentCtrl.text,
                    newPassword: _newCtrl.text,
                  );
                  setState(() => _loading = false);
                  if (context.mounted) Navigator.pop(context, ok);
                },
                child: Text("Save", style: TextStyle(color: Colors.white)),
              ),
      ],
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PassField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
