import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class ChangeNameDialog extends StatefulWidget {
  final String? currentName;
  final Future<bool> Function(String newName) onSave;

  const ChangeNameDialog({
    super.key,
    required this.currentName,
    required this.onSave,
  });

  @override
  State<ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends State<ChangeNameDialog> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName ?? '');
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
        "Change Name",
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: "New Name",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(Icons.person_outline),
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
