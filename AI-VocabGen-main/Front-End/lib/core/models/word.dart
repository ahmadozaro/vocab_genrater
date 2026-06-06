class WordModel {
  final int wordId;
  final String text;
  final String? arabicMeaning;
  final String? audio;
  final String? source;
  final String? definition;
  final String? translationAr;
  final String? status;
  final int sm2Repeats;
  final double sm2EaseFactor;
  final int sm2IntervalDays;
  final String? nextReviewDate;
  final String? lastReviewedAt;
  final int correctStreak;
  final int wrongStreak;
  final int score;
  final String? addedAt;
  final List<String> examples;

  WordModel({
    required this.wordId,
    required this.text,
    this.arabicMeaning,
    this.audio,
    this.source,
    this.definition,
    this.translationAr,
    this.status,
    required this.sm2Repeats,
    required this.sm2EaseFactor,
    required this.sm2IntervalDays,
    this.nextReviewDate,
    this.lastReviewedAt,
    required this.correctStreak,
    required this.wrongStreak,
    required this.score,
    this.addedAt,
    this.examples = const [],
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      wordId: json['wordId'] ?? json['id'] ?? 0,
      text: json['text'] ?? '',
      arabicMeaning:
          json['arabicMeaning'] ??
          json['translationAr'] ??
          json['translation_ar'] ??
          json['translationText'] ??
          json['translation_text'],
      audio: json['audio'],
      source: json['source'],
      definition: json['definition'] ?? json['aiDefinitionEn'],
      translationAr: json['translationAr'] ?? json['translation_text'],
      status: json['status'],
      sm2Repeats: json['sm2Repeats'] ?? json['sm2_repeats'] ?? 0,
      sm2EaseFactor: (json['sm2EaseFactor'] ?? json['sm2_ease_factor'] ?? 2.5)
          .toDouble(),
      sm2IntervalDays:
          json['sm2IntervalDays'] ?? json['sm2_interval_days'] ?? 0,
      nextReviewDate:
          json['nextReviewDate']?.toString() ??
          json['next_review_at']?.toString(),
      lastReviewedAt:
          json['lastReviewedAt']?.toString() ??
          json['last_reviewed_at']?.toString(),
      correctStreak: json['correctStreak'] ?? json['correct_streak'] ?? 0,
      wrongStreak: json['wrongStreak'] ?? json['wrong_streak'] ?? 0,
      score: json['score'] ?? 0,
      addedAt: json['addedAt']?.toString(),
      examples: List<String>.from(json['examples'] ?? []),
    );
  }
}
