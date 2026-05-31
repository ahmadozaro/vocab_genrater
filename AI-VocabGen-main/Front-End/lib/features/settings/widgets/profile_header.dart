import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

// ─── قائمة الأفاتارات المتاحة ─────────────────────────────────
List<Map<String, dynamic>> kAvatars = [
  {'icon': Icons.face, 'color': Color(0xFF4C6FFF)},
  {'icon': Icons.face_2, 'color': Color(0xFFFF6B6B)},
  {'icon': Icons.face_3, 'color': Color(0xFF6BCB77)},
  {'icon': Icons.face_4, 'color': Color(0xFFFFD93D)},
  {'icon': Icons.face_5, 'color': Color(0xFFFF9A3C)},
  {'icon': Icons.face_6, 'color': Color(0xFF9B59B6)},
  {'icon': Icons.sentiment_satisfied_alt, 'color': Color(0xFF00B4D8)},
  {'icon': Icons.sentiment_very_satisfied, 'color': Color(0xFF06D6A0)},
  {'icon': Icons.catching_pokemon, 'color': Color(0xFFFF6B6B)},
  {'icon': Icons.sports_esports, 'color': Color(0xFF4C6FFF)},
  {'icon': Icons.school, 'color': Color(0xFF6BCB77)},
  {'icon': Icons.auto_awesome, 'color': Color(0xFFFFD93D)},
];

// ─── لون بج المستوى ───────────────────────────────────────────
Color _levelColor(String? level) {
  switch (level) {
    case 'A1':
      return Color(0xFF9E9E9E);
    case 'A2':
      return Color(0xFF6BCB77);
    case 'B1':
      return Color(0xFF4C6FFF);
    case 'B2':
      return Color(0xFFFF9A3C);
    case 'C1':
      return Color(0xFFFF6B6B);
    default:
      return AppColors.primary;
  }
}

class ProfileHeader extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final String? userLevel;
  final int selectedAvatarIndex;
  final VoidCallback onPickAvatar;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userLevel,
    required this.selectedAvatarIndex,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = kAvatars[selectedAvatarIndex % kAvatars.length];

    return Center(
      child: Column(
        children: [
          // ─── الأفاتار ──────────────────────────────────────
          Stack(
            children: [
              GestureDetector(
                onTap: onPickAvatar,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: (avatar['color'] as Color).withOpacity(0.15),
                  child: Icon(
                    avatar['icon'] as IconData,
                    size: 50,
                    color: avatar['color'] as Color,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickAvatar,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.edit, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // ─── الاسم ────────────────────────────────────────
          Text(
            userName ?? 'User',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),

          // ─── الإيميل ──────────────────────────────────────
          Text(
            userEmail ?? '',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          SizedBox(height: 8),

          // ─── بج المستوى — يتحدث تلقائياً ─────────────────
          AnimatedContainer(
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _levelColor(userLevel).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _levelColor(userLevel).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.military_tech,
                  size: 16,
                  color: _levelColor(userLevel),
                ),
                SizedBox(width: 4),
                Text(
                  userLevel != null
                      ? "Level: $userLevel"
                      : "Take the test first",
                  style: TextStyle(
                    color: _levelColor(userLevel),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
