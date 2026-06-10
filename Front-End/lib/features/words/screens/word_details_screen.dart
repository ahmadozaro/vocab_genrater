
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/providers/notification_provider.dart';
import 'package:ai/core/services/api.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class WordDetailsScreen extends StatefulWidget {
  final int wordId;

  const WordDetailsScreen({super.key, required this.wordId});

  @override
  State<WordDetailsScreen> createState() => _WordDetailsScreenState();
}

class _WordDetailsScreenState extends State<WordDetailsScreen> {
  WordModel? _word;
  bool _isLoading = true;
  String? _error;
  bool _isDeleting = false;
  bool _isPlayingAudio = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isPlayingAudio) return;

    setState(() => _isPlayingAudio = true);

    try {
      String audioUrl = _word?.audio ?? '';

      
      if (audioUrl.isEmpty && _word != null) {
        audioUrl =
            'https://ssl.gstatic.com/dictionary/static/sounds/oxford/${_word!.text.toLowerCase()}.mp3';
      }

      if (audioUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد نطق متاح 🔇'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isPlayingAudio = false);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر تشغيل النطق: ${e.toString()} 🔈'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
      }
    }
  }

  Future<void> _loadWord() async {
    final wordProvider = context.read<WordProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _word = await ApiService.getWord(widget.wordId);
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      if (message.contains('404')) {
        _error = 'This word was deleted';
        await wordProvider.deleteWordFromCache(widget.wordId);
      } else {
        _error = message;
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text(
          'Are you sure you want to delete this word from your words?',
        ),
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
    setState(() => _isDeleting = true);
    try {
      await ApiService.deleteWord(widget.wordId);
      if (!mounted) return;
      await Future.wait([
        context.read<WordProvider>().loadWords(),
        context.read<ProgressProvider>().refresh(),
        context.read<NotificationProvider>().sync(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حذف الكلمة بنجاح'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: _word?.text ?? 'Word Details',
        subtitle: _word?.arabicMeaning ?? '',
        icon: Icons.menu_book_rounded,
        metricLabel: 'Status',
        metricValue: _word?.status?.toUpperCase() ?? '',
        showBackButton: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 56),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    final word = _word!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _copyToClipboard(word.text),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.text,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    word.arabicMeaning ?? 'No Arabic meaning',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.24),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          word.status?.toUpperCase() ?? 'NEW',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isPlayingAudio ? null : _playAudio,
                        icon: _isPlayingAudio
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryDark,
                                  ),
                                ),
                              )
                            : const Icon(Icons.volume_up, size: 18),
                        label: Text(_isPlayingAudio ? 'Playing...' : 'Play'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          disabledForegroundColor:
                              AppColors.primaryDark.withOpacity(0.38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.copy, size: 14, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        'Tap to copy the word',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _DetailCard(
            title: 'Definition',
            child: Text(
              word.definition?.isNotEmpty == true
                  ? word.definition!
                  : 'Definition not available',
              style: TextStyle(
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Pronunciation',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    word.audio != null && word.audio!.isNotEmpty
                        ? 'Tap Play to hear the pronunciation.'
                        : 'Tap Play to hear the pronunciation (powered by Oxford Dictionary).',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ),
                IconButton(
                  onPressed: _isPlayingAudio ? null : _playAudio,
                  icon: _isPlayingAudio
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(Icons.headphones, color: AppColors.primary),
                  tooltip: 'Play pronunciation',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Example Sentences',
            child: word.examples.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: word.examples
                        .map((example) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 18)),
                                  Expanded(
                                    child: Text(
                                      example,
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  )
                : Text(
                    'No examples yet.',
                    style: TextStyle(color: AppColors.textLight),
                  ),
          ),
          if (word.source != null && word.source!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Source',
              child: Text(
                word.source!,
                style: TextStyle(color: AppColors.textDark),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Learning Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoBox(label: 'Score', value: '${word.score}'),
              _InfoBox(label: 'Repeats', value: '${word.sm2Repeats}'),
              _InfoBox(
                label: 'Ease',
                value: word.sm2EaseFactor.toStringAsFixed(2),
              ),
              _InfoBox(label: 'Interval', value: '${word.sm2IntervalDays}d'),
              _InfoBox(label: 'Correct Streak', value: '${word.correctStreak}'),
              _InfoBox(label: 'Wrong Streak', value: '${word.wrongStreak}'),
            ],
          ),
          const SizedBox(height: 24),
          _InfoRow(
              title: 'Next Review', value: word.nextReviewDate ?? 'Due now'),
          _InfoRow(
              title: 'Last Reviewed',
              value: word.lastReviewedAt ?? 'Not reviewed yet'),
          if (word.addedAt != null)
            _InfoRow(title: 'Added', value: word.addedAt!),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDeleting ? null : _deleteWord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(
                _isDeleting ? 'Deleting...' : 'Delete Word',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('English word copied to clipboard'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary.withOpacity(0.18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.textLight),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
