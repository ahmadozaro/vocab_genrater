import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class ChangeEmailDialog extends StatefulWidget {
  final String? currentEmail;
  final Future<bool> Function(String newEmail) onSave;

  const ChangeEmailDialog({
    super.key,
    required this.currentEmail,
    required this.onSave,
  });

  @override
  State<ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<ChangeEmailDialog> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentEmail ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "Change Email",
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: "New Email",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(Icons.email_outlined),
        ),
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
                  setState(() => _loading = true);
                  final ok = await widget.onSave(_ctrl.text.trim());
                  setState(() => _loading = false);
                  if (context.mounted) Navigator.pop(context, ok);
                },
                child: Text("Save", style: TextStyle(color: Colors.white)),
              ),
      ],
    );
  }
}
