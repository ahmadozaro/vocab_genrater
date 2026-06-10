import 'dart:async';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/add_word/widgets/word_list_item.dart';
import 'package:ai/features/add_word/widgets/word_result_card.dart';
import 'package:ai/features/add_word/widgets/suggested_words.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/services/api.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/button.dart';
import 'package:ai/core/widgets/appbar.dart';
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
  final _listSearchController = TextEditingController();
  final _wordsScrollController = ScrollController();
  late TabController _tabController;
  Timer? _translationDebounce;
  String? _lastAutoArabic;
  bool _isTranslating = false;
  int _translationRequestId = 0;

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 3, vsync: this);
    _wordController.addListener(_onWordChanged);
    _wordsScrollController.addListener(_onWordsScrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WordProvider>().loadWords();
    });
  }

  @override
  void dispose() {
    _translationDebounce?.cancel();
    _wordsScrollController.removeListener(_onWordsScrolled);
    _wordController.removeListener(_onWordChanged);
    _wordController.dispose();
    _arabicController.dispose();
    _listSearchController.dispose();
    _wordsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onWordsScrolled() {
    if (!_wordsScrollController.hasClients) return;
    final position = _wordsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      context.read<WordProvider>().loadMoreWords();
    }
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
        final meaning = (result['arabicMeaning'] ??
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
        await _search(preserveArabic: true);
        setState(() {});
      } catch (_) {
        
      } finally {
        if (mounted && activeRequestId == _translationRequestId) {
          setState(() => _isTranslating = false);
        }
      }
    });
  }

  Future<void> _search({bool preserveArabic = false}) async {
    final provider = context.read<WordProvider>();
    FocusScope.of(context).unfocus();
    if (!preserveArabic) {
      _arabicController.clear();
    }
    await provider.searchWord(_wordController.text);
    final result = provider.searchResult;
    if (result?.arabicMeaning != null && mounted) {
      if (!preserveArabic ||
          _arabicController.text.isEmpty ||
          _arabicController.text == _lastAutoArabic) {
        _arabicController.text = result!.arabicMeaning!;
      }
    }
  }

  Future<void> _save() async {
    final provider = context.read<WordProvider>();
    if (_arabicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء إدخال المعنى بالعربية ⚠️'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final status = await provider.saveWord(
      _wordController.text.trim(),
      _arabicController.text.trim(),
    );
    if (!mounted) return;
    if (status != null) {
      context.read<ProgressProvider>().refresh();
      context.read<WordProvider>().loadWords(forceRefresh: true);
      _lastAutoArabic = null;
      _wordController.clear();
      _arabicController.clear();
      final message = status == 'pending'
          ? 'تم الحفظ في قائمة الانتظار (ستُفعَّل غداً)'
          : 'تم الحفظ بنجاح';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      _tabController.animateTo(2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'فشل في الحفظ'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'new':
        return 'New';
      case 'learning':
        return 'Learning';
      case 'review':
        return 'Review';
      case 'hard':
        return 'Hard';
      case 'mastered':
        return 'Mastered';
      default:
        return status ?? 'Filter';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordsCount = context.watch<WordProvider>().words.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: "Words",
        subtitle: "Build and review your vocabulary",
        icon: Icons.menu_book_rounded,
        metricLabel: "Words",
        metricValue: "$wordsCount",
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          
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
          
          SuggestedWordsTab(tabController: _tabController),
          _buildListTab(),
        ],
      ),
    );
  }

  
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
                  PressableScale(
                    onTap: provider.searchState == WordSearchState.loading
                        ? null
                        : _search,
                    enabled: provider.searchState != WordSearchState.loading,
                    borderRadius: BorderRadius.circular(12),
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
                AnimatedEntry(
                  child: WordResultCard(
                    word: provider.searchResult ??
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

  
  Widget _buildListTab() {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingWords && provider.words.isEmpty) {
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
            if (provider.offlineMode)
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.35)),
                ),
                child: Text(
                  "Offline mode active",
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _listSearchController,
                      onChanged: provider.updateWordSearchFilter,
                      decoration: InputDecoration(
                        hintText: "Search words",
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  PopupMenuButton<String?>(
                    tooltip: "Filter",
                    onSelected: provider.updateStatusFilter,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: null, child: Text("All")),
                      PopupMenuItem(value: "new", child: Text("New")),
                      PopupMenuItem(value: "learning", child: Text("Learning")),
                      PopupMenuItem(value: "review", child: Text("Review")),
                      PopupMenuItem(value: "hard", child: Text("Hard")),
                      PopupMenuItem(value: "mastered", child: Text("Mastered")),
                    ],
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.filter_list, color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    tooltip: "Refresh",
                    onPressed: () => provider.loadWords(forceRefresh: true),
                    icon: Icon(Icons.refresh, color: AppColors.primary),
                  ),
                ],
              ),
            ),
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
                    value: "${provider.totalWords}",
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
            if (provider.statusFilter != null) ...[
              SizedBox(height: 12),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtered by ${_statusLabel(provider.statusFilter)}. Tap Clear to show all words.',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => provider.updateStatusFilter(null),
                      child: Text('Clear'),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Words Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${provider.words.length} words in your vocabulary',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      provider.words.isEmpty ? 'Empty' : 'Sorted by status',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.sortedWords.isEmpty && !provider.isLoadingMore
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox,
                                size: 56, color: AppColors.textLight),
                            SizedBox(height: 16),
                            Text(
                              provider.statusFilter != null
                                  ? 'No words match this filter.'
                                  : 'No words yet!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              provider.statusFilter != null
                                  ? 'Try clearing the filter or add new words to see them here.'
                                  : 'Add your first word to get started.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (provider.statusFilter != null) ...[
                              SizedBox(height: 16),
                              TextButton(
                                onPressed: () =>
                                    provider.updateStatusFilter(null),
                                child: Text('Show all words'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _wordsScrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.sortedWords.length +
                          (provider.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i >= provider.sortedWords.length) {
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final word = provider.sortedWords[i];
                        return AnimatedEntry(
                          index: i,
                          child: WordListItem(
                            word: word,
                            onDelete: () => _deleteWordWithUndo(provider, word),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWordWithUndo(
      WordProvider provider, WordModel word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text(
            'Are you sure you want to delete "${word.text}" from My Words?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await provider.deleteWord(word.wordId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Failed to delete word"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${word.text}" deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => provider.restoreWord(word.wordId),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

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
