import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/models/notification.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/core/providers/notification_provider.dart';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:ai/features/words/screens/word_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WordProvider>().loadWords();
      context.read<ProgressProvider>().load();
      context.read<NotificationProvider>().sync();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<WordProvider>().loadWords(),
      context.read<ProgressProvider>().refresh(),
      context.read<NotificationProvider>().sync(),
    ]);
  }

  void _showNotifications(BuildContext context) {
    final notifProvider = context.read<NotificationProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return NotificationSheet(
              provider: notifProvider,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<WordProvider, ProgressProvider, NotificationProvider>(
      builder: (context, wordsProvider, progressProvider, notifProvider, _) {
        final isLoading =
            (wordsProvider.isLoadingWords && wordsProvider.words.isEmpty) ||
            (progressProvider.isLoading && !progressProvider.hasLoaded);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: LearningAppBar(
            title: "Let's Learn",
            subtitle: "Welcome back to your vocabulary path",
            icon: Icons.auto_stories_rounded,
            metricLabel: "Streak",
            metricValue: "${progressProvider.dailyStreak}",
            actions: [
              const SizedBox(width: 8),
              _NotificationBell(
                unreadCount: notifProvider.unreadCount,
                onTap: () => _showNotifications(context),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(20),
                      child: _HomeContent(
                        progressProvider: progressProvider,
                        words: wordsProvider.words,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  final ProgressProvider progressProvider;
  final List<WordModel> words;

  const _HomeContent({required this.progressProvider, required this.words});

  @override
  Widget build(BuildContext context) {
    if (progressProvider.errorMessage != null) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          progressProvider.errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textDark),
        ),
      );
    }

    final active = progressProvider.activeWordsCount;
    final mastered = progressProvider.masteredWords;
    final streak = progressProvider.dailyStreak;
    final dueCount = progressProvider.dueReviewCount;
    final dailyValue = active == 0 ? 0.0 : (active / 10.0).clamp(0.0, 1.0);
    final dueWords = words
        .where((w) => (w.status ?? '') != 'pending')
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedEntry(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9F7BFF), Color(0xFF755DC1)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Words Today',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '$active / 10 Words',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                AnimatedProgressBar(
                  value: dailyValue,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  minHeight: 8,
                ),
                SizedBox(height: 8),
                Text(
                  dueCount > 0
                      ? 'You have $dueCount words ready for SM2 review.'
                      : 'No words due right now. Keep adding and reviewing.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AnimatedEntry(
                index: 1,
                child: _StatCard(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '$streak Days',
                  color: AppColors.warning,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: AnimatedEntry(
                index: 2,
                child: _StatCard(
                  icon: Icons.star,
                  label: 'Mastered',
                  value: '$mastered Words',
                  color: AppColors.success,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: AnimatedEntry(
                index: 3,
                child: _StatCard(
                  icon: Icons.access_time,
                  label: 'Due Today',
                  value: '$dueCount Cards',
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Text(
          'Words Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        if (dueWords.isEmpty)
          Text(
            'No words yet. Add your first word from the Words tab.',
            style: TextStyle(color: AppColors.textLight),
          )
        else
          ...dueWords.asMap().entries.map(
            (entry) => AnimatedEntry(
              index: entry.key + 4,
              child: _WordCard(
                wordId: entry.value.wordId,
                word: entry.value.text,
                meaning: entry.value.arabicMeaning ?? '',
                level: entry.value.status ?? 'new',
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedLearningCard(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationSheet extends StatelessWidget {
  final NotificationProvider provider;
  final ScrollController scrollController;

  const NotificationSheet({
    super.key,
    required this.provider,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final notifs = provider.notifications;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (provider.unreadCount > 0)
                TextButton(
                  onPressed: () {
                    provider.markAllRead();
                  },
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (notifs.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: notifs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = notifs[index];
                  return _NotificationTile(notif: notif, provider: provider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notif;
  final NotificationProvider provider;

  const _NotificationTile({required this.notif, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Icon(
        _iconForType(notif.type),
        color: notif.isRead ? AppColors.textLight : AppColors.primary,
        size: 24,
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
          color: AppColors.textDark,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        notif.message,
        style: TextStyle(
          color: AppColors.textLight,
          fontSize: 12,
        ),
      ),
      trailing: notif.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        if (!notif.isRead) {
          provider.markRead(notif.id);
        }
      },
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'welcome':
        return Icons.waving_hand;
      case 'sm2_due':
        return Icons.quiz;
      case 'streak_reminder':
        return Icons.local_fire_department;
      case 'hard_words':
        return Icons.warning_amber;
      case 'pending_words':
        return Icons.hourglass_bottom;
      default:
        return Icons.notifications;
    }
  }
}

class _WordCard extends StatelessWidget {
  final int wordId;
  final String word;
  final String meaning;
  final String level;

  const _WordCard({
    required this.wordId,
    required this.word,
    required this.meaning,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedLearningCard(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () {
        Navigator.push(
          context,
          AppMotion.sharedRoute(WordDetailsScreen(wordId: wordId)),
        );
      },
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              level,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  meaning,
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
