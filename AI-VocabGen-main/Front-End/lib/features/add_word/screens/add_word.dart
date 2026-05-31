import 'dart:async';

import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/add_word/widgets/word_list_item.dart';
import 'package:ai/features/add_word/widgets/word_result_card.dart';
import 'package:ai/features/add_word/widgets/suggested_words.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/services/api.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/button.dart';
import 'package:ai/core/widgets/textfield.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen>
    with SingleTickerProviderStateMixin {
  final _wordController = TextEditingController();
  final _arabicController = TextEditingController();
  late TabController _tabController;
  Timer? _translationDebounce;
  String? _lastAutoArabic;
  bool _isTranslating = false;
  int _translationRequestId = 0;

  @override
  void initState() {
    super.initState();
    // ✅ 3 تابات
    _tabController = TabController(length: 3, vsync: this);
    _wordController.addListener(_onWordChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WordProvider>().loadWords();
    });
  }

  @override
  void dispose() {
    _translationDebounce?.cancel();
    _wordController.removeListener(_onWordChanged);
    _wordController.dispose();
    _arabicController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onWordChanged() {
    setState(() {});
    final text = _wordController.text.trim();
    final requestId = ++_translationRequestId;
    final provider = context.read<WordProvider>();
    if (provider.searchResult != null &&
        provider.searchResult!.text.toLowerCase() != text.toLowerCase()) {
      provider.clearSearch();
    }
    _translationDebounce?.cancel();
    if (text.isEmpty) {
      _arabicController.clear();
      _lastAutoArabic = null;
      provider.clearSearch();
      setState(() => _isTranslating = false);
      return;
    }

    if (text.length < 2) {
      if (_arabicController.text == _lastAutoArabic) {
        _arabicController.clear();
        _lastAutoArabic = null;
      }
      provider.clearSearch();
      setState(() => _isTranslating = false);
      return;
    }

    _translationDebounce = Timer(Duration(milliseconds: 600), () async {
      final requestedText = _wordController.text.trim();
      final activeRequestId = requestId;
      if (requestedText.length < 2) return;
      setState(() => _isTranslating = true);
      try {
        final result = await ApiService.translateInstant(requestedText);
        if (!mounted ||
            _wordController.text.trim() != requestedText ||
            activeRequestId != _translationRequestId) {
          return;
        }
        final meaning =
            (result['arabicMeaning'] ??
                    result['translationAr'] ??
                    result['translation_ar'] ??
                    result['translationText'] ??
                    result['translation_text'] ??
                    '')
                .toString();
        if (meaning.isNotEmpty &&
            (_arabicController.text.isEmpty ||
                _arabicController.text == _lastAutoArabic)) {
          _lastAutoArabic = meaning;
          _arabicController.text = meaning;
        }
        setState(() {});
      } catch (_) {
        // Silent: the user can still type the Arabic meaning manually.
      } finally {
        if (mounted && activeRequestId == _translationRequestId) {
          setState(() => _isTranslating = false);
        }
      }
    });
  }

  Future<void> _search() async {
    final provider = context.read<WordProvider>();
    FocusScope.of(context).unfocus();
    _arabicController.clear();
    await provider.searchWord(_wordController.text);
    final result = provider.searchResult;
    if (result?.arabicMeaning != null && mounted) {
      _arabicController.text = result!.arabicMeaning!;
    }
  }

  Future<void> _save() async {
    final provider = context.read<WordProvider>();
    if (_arabicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter the Arabic meaning"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final ok = await provider.saveWord(
      _wordController.text.trim(),
      _arabicController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      context.read<ProgressProvider>().refresh();
      _lastAutoArabic = null;
      _wordController.clear();
      _arabicController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Word saved successfully! ✅"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // ✅ الانتقال لـ My Words (التاب 2 الآن)
      _tabController.animateTo(2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to save'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _addTestWords(WordProvider provider) async {
    final testWords = [
      {'text': 'Postpone', 'arabic': 'تأجيل'},
      {'text': 'Eloquent', 'arabic': 'فصيح'},
      {'text': 'Ambiguous', 'arabic': 'غامض'},
      {'text': 'Diligent', 'arabic': 'مجتهد'},
    ];

    int added = 0;
    for (final word in testWords) {
      try {
        await ApiService.createWord(
          text: word['text']!,
          arabicMeaning: word['arabic']!,
          audio: null,
          source: 'test',
        );
        added++;
      } catch (_) {}
    }

    await provider.loadWords();
    if (mounted) context.read<ProgressProvider>().refresh();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0 ? "$added test words added ✅" : "Words already exist",
        ),
        backgroundColor: added > 0 ? AppColors.success : AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (added > 0) _tabController.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Words",
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          // ✅ 3 تابات
          tabs: [
            Tab(icon: Icon(Icons.add), text: "Add Word"),
            Tab(icon: Icon(Icons.auto_awesome), text: "Suggested"),
            Tab(icon: Icon(Icons.list), text: "My Words"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddTab(),
          // ✅ تاب الكلمات المقترحة
          SuggestedWordsTab(tabController: _tabController),
          _buildListTab(),
        ],
      ),
    );
  }

  // ─── تاب الإضافة ───────────────────────────────────────────
  Widget _buildAddTab() {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter an English word",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: "e.g. Postpone",
                      controller: _wordController,
                    ),
                  ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: provider.searchState == WordSearchState.loading
                        ? null
                        : _search,
                    child: Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9F7BFF), Color(0xFF755DC1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: provider.searchState == WordSearchState.loading
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              if (_isTranslating)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Translating...",
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),

              if (provider.searchState == WordSearchState.error)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage ?? 'Word not found',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_wordController.text.trim().isNotEmpty) ...[
                WordResultCard(
                  word:
                      provider.searchResult ??
                      WordModel(
                        wordId: 0,
                        text: _wordController.text.trim(),
                        arabicMeaning: _arabicController.text.trim().isEmpty
                            ? null
                            : _arabicController.text.trim(),
                        definition: null,
                        status: 'new',
                        sm2Repeats: 0,
                        sm2EaseFactor: 2.5,
                        sm2IntervalDays: 0,
                        correctStreak: 0,
                        wrongStreak: 0,
                        score: 0,
                      ),
                  arabicController: _arabicController,
                ),
                SizedBox(height: 20),
                CustomButton(
                  text: "Save to My Words",
                  isLoading: provider.isSaving,
                  onPressed: provider.isSaving ? null : _save,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── تاب القائمة ───────────────────────────────────────────
  Widget _buildListTab() {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingWords) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (provider.words.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 80,
                  color: AppColors.textLight.withOpacity(0.4),
                ),
                SizedBox(height: 16),
                Text(
                  "No words yet!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Add your first word to get started",
                  style: TextStyle(color: AppColors.textLight),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
                    "Add Word",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => _tabController.animateTo(0),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: "Total",
                    value: "${provider.words.length}",
                    icon: Icons.library_books,
                  ),
                  _StatItem(
                    label: "Learned",
                    value:
                        "${provider.words.where((w) => w.score >= 3).length}",
                    icon: Icons.check_circle,
                  ),
                  _StatItem(
                    label: "To Review",
                    value: "${provider.words.where((w) => w.score < 3).length}",
                    icon: Icons.refresh,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: provider.words.length,
                itemBuilder: (_, i) => WordListItem(word: provider.words[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
