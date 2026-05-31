class Testslevel {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String hint;
  final String difficulty; // 'easy' | 'medium' | 'hard'

  const Testslevel({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.hint,
    required this.difficulty,
  });
}

const List<Testslevel> testsQuestions = [
  //سهل (A1-A2)
  Testslevel(
    text:
        "1. I need to buy some ________ for my salad, like lettuce and tomatoes.",
    options: ["stationery", "vegetables", "appliances", "furniture"],
    correctIndex: 1,
    hint: "أشياء خضراء نأكلها في السلطة",
    difficulty: 'easy',
  ),
  Testslevel(
    text:
        "2. My sister is a ________; she works in a large hospital and helps sick people.",
    options: ["carpenter", "lawyer", "nurse", "pilot"],
    correctIndex: 2,
    hint: "شخص يساعد الأطباء والمرضى",
    difficulty: 'easy',
  ),
  Testslevel(
    text: "3. It's very ________ today; you should take an umbrella.",
    options: ["sunny", "rainy", "thirsty", "hungry"],
    correctIndex: 1,
    hint: "حالة الجو عندما تسقط المياه من السماء",
    difficulty: 'easy',
  ),
  // متوسط (B1-B2)
  Testslevel(
    text: "4. The company decided to ________ the meeting until next Tuesday.",
    options: ["cancel", "postpone", "confirm", "interrupt"],
    correctIndex: 1,
    hint: "تغيير موعد شيء ليكون في وقت لاحق",
    difficulty: 'medium',
  ),
  Testslevel(
    text:
        "5. She has a very ________ lifestyle; she exercises every day and eats organic food.",
    options: ["hectic", "cautious", "healthy", "sedentary"],
    correctIndex: 2,
    hint: "أسلوب حياة يحافظ على سلامة الجسم",
    difficulty: 'medium',
  ),
  Testslevel(
    text:
        "6. I didn't mean to ________ you, but I think you've made a mistake in the calculations.",
    options: ["offend", "defend", "depend", "pretend"],
    correctIndex: 0,
    hint: "التسبب في ضيق أو إحراج لشخص ما",
    difficulty: 'medium',
  ),
  // صعب (C1)
  Testslevel(
    text:
        "7. The speaker's ________ argument convinced the entire audience to support the new policy.",
    options: ["tenuous", "cogent", "vague", "sluggish"],
    correctIndex: 1,
    hint: "وصف للحجة القوية والمنطقية التي تقنع الآخرين",
    difficulty: 'hard',
  ),
  Testslevel(
    text:
        "8. After years of war, the citizens were longing for a period of ________ and stability.",
    options: ["turbulence", "tranquility", "friction", "chaos"],
    correctIndex: 1,
    hint: "حالة من الهدوء الشديد والسكينة",
    difficulty: 'hard',
  ),
  Testslevel(
    text:
        "9. His ________ remarks during the ceremony were considered highly inappropriate by the committee.",
    options: ["facetious", "meticulous", "diligent", "gregarious"],
    correctIndex: 0,
    hint: "محاولة المزاح في مواقف جادة أو غير مناسبة",
    difficulty: 'hard',
  ),
  Testslevel(
    text:
        "10. The scientist's discovery was so ________ that it completely changed our understanding of physics.",
    options: ["ephemeral", "profound", "trivial", "obsolete"],
    correctIndex: 1,
    hint: "شيء ذو تأثير عميق وجذري وليس سطحياً",
    difficulty: 'hard',
  ),
];
