import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              "My Progress",
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          body: provider.isLoading && !provider.hasLoaded
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20),
                    child: _ProgressContent(provider: provider),
                  ),
                ),
        );
      },
    );
  }
}

class _ProgressContent extends StatelessWidget {
  final ProgressProvider provider;

  const _ProgressContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.errorMessage != null) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          provider.errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textDark),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.white, size: 42),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Daily streak", style: TextStyle(color: Colors.white70)),
                  Text(
                    "${provider.dailyStreak} days",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Overview",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _ProgressCard(
              title: "SM2 Quizzes",
              value: "${provider.completedSm2Quizzes}",
              icon: Icons.quiz,
              color: AppColors.primary,
            ),
            _ProgressCard(
              title: "Mastered",
              value: "${provider.masteredWords}",
              icon: Icons.star,
              color: AppColors.success,
            ),
            _ProgressCard(
              title: "Active Words",
              value: "${provider.activeWordsCount}",
              icon: Icons.book,
              color: AppColors.warning,
            ),
            _ProgressCard(
              title: "Due Reviews",
              value: "${provider.dueReviewCount}",
              icon: Icons.refresh,
              color: AppColors.error,
            ),
          ],
        ),
        SizedBox(height: 20),
        _InfoTile(label: "Overdue", value: "${provider.overdueCount}"),
        _InfoTile(label: "Hard words", value: "${provider.hardCount}"),
        _InfoTile(label: "Pending words", value: "${provider.pendingCount}"),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: AppColors.textDark)),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
