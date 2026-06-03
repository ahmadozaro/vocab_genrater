import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class WordResultCard extends StatefulWidget {
  final WordModel word;
  final TextEditingController arabicController;

  const WordResultCard({
    super.key,
    required this.word,
    required this.arabicController,
  });

  @override
  State<WordResultCard> createState() => _WordResultCardState();
}

class _WordResultCardState extends State<WordResultCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    final audio = widget.word.audio;
    if (audio == null || audio.isEmpty) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audio));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to play audio')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.word.definition;

    return AnimatedLearningCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.word.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (widget.word.audio != null)
                IconButton(
                  tooltip: 'Play pronunciation',
                  onPressed: _playAudio,
                  icon: Icon(Icons.volume_up, color: AppColors.primary),
                ),
            ],
          ),
          Divider(height: 28),
          _Label(text: 'Definition'),
          SizedBox(height: 4),
          Text(
            definition == null || definition.isEmpty
                ? 'No definition found yet.'
                : definition,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          _Label(text: 'Arabic meaning'),
          SizedBox(height: 8),
          TextField(
            controller: widget.arabicController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'اكتب المعنى بالعربية...',
              hintTextDirection: TextDirection.rtl,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          if (widget.word.examples.isNotEmpty) ...[
            SizedBox(height: 16),
            _Label(text: 'Examples'),
            SizedBox(height: 8),
            ...widget.word.examples.map(
              (example) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        example,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textLight,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
