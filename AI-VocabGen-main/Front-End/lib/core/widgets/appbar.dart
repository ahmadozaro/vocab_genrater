import 'package:ai/core/theme/colors.dart';
import 'package:flutter/material.dart';

class LearningAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? metricLabel;
  final String? metricValue;
  final double? progress;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final Widget? leading;
  final List<Widget>? actions;

  const LearningAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.metricLabel,
    this.metricValue,
    this.progress,
    this.bottom,
    this.showBackButton = false,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize {
    final baseHeight = progress == null ? 116.0 : 138.0;
    return Size.fromHeight(baseHeight + (bottom?.preferredSize.height ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final bottomWidget = bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.secondary,
            AppColors.primary,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                showBackButton || leading != null ? 8 : 18,
                14,
                18,
                progress == null ? 16 : 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (leading != null)
                        leading!
                      else if (showBackButton)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      if (showBackButton || leading != null)
                        const SizedBox(width: 2),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (metricLabel != null && metricValue != null) ...[
                        const SizedBox(width: 12),
                        _LearningAppBarMetric(
                          label: metricLabel!,
                          value: metricValue!,
                        ),
                      ],
                      if (actions != null) ...actions!,
                    ],
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress!.clamp(0.0, 1.0),
                              minHeight: 9,
                              backgroundColor: Colors.white.withOpacity(0.22),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 44,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "${(progress!.clamp(0.0, 1.0) * 100).round()}%",
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (bottomWidget != null)
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.white.withOpacity(0.14),
                  highlightColor: Colors.white.withOpacity(0.08),
                ),
                child: bottomWidget,
              ),
          ],
        ),
      ),
    );
  }
}

class _LearningAppBarMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LearningAppBarMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 62, maxWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
