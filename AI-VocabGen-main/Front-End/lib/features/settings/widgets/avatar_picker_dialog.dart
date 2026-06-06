import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';
import 'profile_header.dart';

class AvatarPickerDialog extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const AvatarPickerDialog({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Choose Avatar",
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 300,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: kAvatars.length,
          itemBuilder: (_, i) {
            final avatar = kAvatars[i];
            final isSelected = i == currentIndex;
            return GestureDetector(
              onTap: () {
                onSelect(i);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (avatar['color'] as Color).withOpacity(
                    isSelected ? 0.3 : 0.1,
                  ),
                  border: isSelected
                      ? Border.all(color: avatar['color'] as Color, width: 2.5)
                      : null,
                ),
                child: Icon(
                  avatar['icon'] as IconData,
                  size: 30,
                  color: avatar['color'] as Color,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: AppColors.textLight)),
        ),
      ],
    );
  }
}
