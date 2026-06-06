import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class QuizFillBlankWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  const QuizFillBlankWidget({
    super.key,
    required this.controller,
    this.enabled = true,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: "Type your answer...",
        hintTextDirection: TextDirection.ltr,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: TextStyle(fontSize: 16),
      onChanged: (val) {
        if (val.trim().isNotEmpty) {
          onSubmitted(val.trim());
        }
      },
      onSubmitted: (val) {
        if (val.trim().isNotEmpty) {
          onSubmitted(val.trim());
        }
      },
    );
  }
}
