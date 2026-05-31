import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/theme/colors.dart';

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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── اسم الكلمة + صوت ────────────────────────────
          Row(
            children: [
              Text(
                widget.word.text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Spacer(),
              if (widget.word.audio != null)
                IconButton(
                  onPressed: _playAudio,
                  icon: Icon(Icons.volume_up, color: AppColors.primary),
                ),
            ],
          ),
          Divider(),
          SizedBox(height: 8),

          // ─── التعريف الإنجليزي ────────────────────────────
          Text(
            "Definition",
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          SizedBox(height: 4),
          Text(
            widget.word.definition ?? '',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),

          // ─── المعنى بالعربي (يدخله المستخدم) ────────────
          Text(
            "المعنى بالعربية",
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          SizedBox(height: 8),
          TextField(
            controller: widget.arabicController,
            decoration: InputDecoration(
              hintText: "أدخل المعنى بالعربية...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),

          // ─── الأمثلة ─────────────────────────────────────
          if (widget.word.examples.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              "Examples",
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            SizedBox(height: 8),
            ...widget.word.examples.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e,
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
