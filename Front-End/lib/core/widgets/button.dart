import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  // أضفنا علامة الاستفهام (?) لجعل الدالة قابلة لاستقبال null عند التعطيل
  final VoidCallback? onPressed;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        // إذا كان يحمل، نعطل الزر بإرسال null، وإلا نرسل الدالة الأصلية
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent, // جعل الخلفية شفافة ليظهر التدرج
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // لون الزر عند التعطيل (أثناء التحميل)
          disabledBackgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: (isLoading || onPressed == null)
                  ? [
                      Color(0xFFBBAAFF),
                      Color(0xFF9E8FD8),
                    ] // ألوان باهتة عند التحميل
                  : [Color(0xFF9F7BFF), Color(0xFF755DC1)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
