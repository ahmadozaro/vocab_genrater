import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/features/add_word/providers/suggested_words_provider.dart';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';

// ─── Model
class SuggestedWordsTab extends StatefulWidget {
  final TabController tabController;

  const SuggestedWordsTab({super.key, required this.tabController});

  @override
  State<SuggestedWordsTab> createState() => _SuggestedWordsTabState();
}

class _SuggestedWordsTabState extends State<SuggestedWordsTab> {
  final SuggestedWordsProvider _provider = SuggestedWordsProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final wordProvider = context.read<WordProvider>();
    await _provider.fetchSuggestions(
      level: auth.userLevel ?? 'B1',
      interests: auth.userInterests,
      existingWords: wordProvider.words.map((w) => w.text).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<SuggestedWordsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return _buildLoading();
          if (provider.error != null) return _buildError(provider);
          if (provider.suggestions.isEmpty) return _buildEmpty();
          return _buildList(provider);
        },
      ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9F7BFF), Color(0xFF755DC1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF755DC1).withOpacity(0.35),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            "AI is picking words for you...",
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────
  Widget _buildError(SuggestedWordsProvider provider) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            SizedBox(height: 16),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text("Try Again", style: TextStyle(color: Colors.white)),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: AppColors.textLight.withOpacity(0.4),
          ),
          SizedBox(height: 16),
          Text(
            "No suggestions yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Tap refresh to get AI suggestions",
            style: TextStyle(color: AppColors.textLight),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.refresh, color: Colors.white),
            label: Text(
              "Get Suggestions",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────
  Widget _buildList(SuggestedWordsProvider provider) {
    final active = provider.activeSuggestions;
    final savedCount = provider.suggestions
        .where((s) => s.state == SuggestedWordState.saved)
        .length;
    final rejectedCount = provider.suggestions
        .where((s) => s.state == SuggestedWordState.rejected)
        .length;

    return Column(
      children: [
        // ─── Header Banner ──────────────────────────────────
        Container(
          margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9F7BFF), Color(0xFF5B3FBF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF755DC1).withOpacity(0.3),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Suggested Words",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "$savedCount saved · $rejectedCount skipped · ${active.length} remaining",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // زر إعادة التحميل
              IconButton(
                onPressed: () {
                  provider.reset();
                  _load();
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // ─── Cards ──────────────────────────────────────────
        if (active.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("🎉", style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    "All done!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "$savedCount words added to your list",
                    style: TextStyle(color: AppColors.textLight),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      "Get More",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      provider.reset();
                      _load();
                    },
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: active.length,
              itemBuilder: (_, i) => _SuggestedWordCard(
                word: active[i],
                onSave: () async {
                  final ok = await provider.saveWord(active[i]);
                  if (!mounted) return;
                  if (ok) {
                    // تحديث قائمة كلماتي
                    context.read<WordProvider>().loadWords();
                    context.read<ProgressProvider>().refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${active[i].text}" added to My Words ✅',
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onReject: () => provider.rejectWord(active[i]),
                onViewWords: () => widget.tabController.animateTo(2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Card Widget ──────────────────────────────────────────────────
class _SuggestedWordCard extends StatefulWidget {
  final SuggestedWord word;
  final VoidCallback onSave;
  final VoidCallback onReject;
  final VoidCallback onViewWords;

  const _SuggestedWordCard({
    required this.word,
    required this.onSave,
    required this.onReject,
    required this.onViewWords,
  });

  @override
  State<_SuggestedWordCard> createState() => _SuggestedWordCardState();
}

class _SuggestedWordCardState extends State<_SuggestedWordCard> {
  bool _expanded = false;

  Color get _difficultyColor {
    switch (widget.word.difficulty) {
      case 'easy':
        return Color(0xFF22C55E);
      case 'hard':
        return Color(0xFFEF4444);
      default:
        return Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = widget.word.state == SuggestedWordState.saved;
    final isSaving = widget.word.state == SuggestedWordState.saving;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSaved ? Color(0xFFF0FDF4) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSaved
              ? Color(0xFF22C55E).withOpacity(0.4)
              : Color(0xFFE8E4F5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Main Row ──────────────────────────────────
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أيقونة الكلمة
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: isSaved
                        ? LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          )
                        : LinearGradient(
                            colors: [Color(0xFF9F7BFF), Color(0xFF755DC1)],
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSaved ? Icons.check_rounded : Icons.text_fields_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),

                // محتوى الكلمة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.word.text,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSaved
                                  ? Color(0xFF16A34A)
                                  : AppColors.textDark,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _difficultyColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.word.difficulty,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _difficultyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        widget.word.arabicMeaning,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.word.definition,
                        maxLines: _expanded ? 10 : 2,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Example (expanded) ─────────────────────────
          if (_expanded)
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.word.example,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Actions ────────────────────────────────────
          if (!isSaved)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE8E4F5), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // زر التوسع
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                      label: Text(
                        _expanded ? "Less" : "Example",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),

                  // فاصل
                  Container(width: 1, height: 24, color: Color(0xFFE8E4F5)),

                  // زر الرفض
                  Expanded(
                    child: TextButton.icon(
                      onPressed: isSaving ? null : widget.onReject,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.error,
                      ),
                      label: Text(
                        "Skip",
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ),

                  // فاصل
                  Container(width: 1, height: 24, color: Color(0xFFE8E4F5)),

                  // زر الحفظ
                  Expanded(
                    child: isSaving
                        ? Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: widget.onSave,
                            icon: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              "Add",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            )
          else
            // حالة المحفوظة
            InkWell(
              onTap: widget.onViewWords,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF22C55E),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Saved to My Words",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
