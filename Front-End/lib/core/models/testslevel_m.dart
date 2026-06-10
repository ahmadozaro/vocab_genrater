class Testslevel {
  final int id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String level; 
  final String hint;

  Testslevel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.level,
    required this.hint,
  });
}


final List<Testslevel> testsQuestions = [
  
  Testslevel(
    id: 1,
    level: 'A1',
    correctIndex: 0,
    text: "She ___ from Spain.",
    options: ["is", "are", "am", "be"],
    hint: "استخدم فعل الكون المناسب للمفرد الغائب.",
  ),
  Testslevel(
    id: 2,
    level: 'A1',
    correctIndex: 1,
    text: "I don't have ___ money.",
    options: ["some", "any", "many", "a"],
    hint: "تُستخدم مع الجمل المنفية للكميات.",
  ),

  
  Testslevel(
    id: 3,
    level: 'A2',
    correctIndex: 2,
    text: "They ___ to the cinema yesterday.",
    options: ["go", "going", "went", "gone"],
    hint: "الجملة في زمن الماضي البسيط (yesterday).",
  ),
  Testslevel(
    id: 4,
    level: 'A2',
    correctIndex: 0,
    text: "This book is ___ than that one.",
    options: ["better", "good", "best", "more good"],
    hint: "صيغة المقارنة بين شيئين (Comparative).",
  ),

  
  Testslevel(
    id: 5,
    level: 'B1',
    correctIndex: 1,
    text: "I have lived here ___ 2015.",
    options: ["for", "since", "from", "in"],
    hint: "تُستخدم للإشارة إلى نقطة زمنية محددة بدأ فيها الفعل.",
  ),
  Testslevel(
    id: 6,
    level: 'B1',
    correctIndex: 2,
    text: "You ___ wear a uniform at our school. It's the rule.",
    options: ["can", "might", "must", "could"],
    hint: "تُستخدم للتعبير عن الإلزام والقواعد الثابتة.",
  ),

  
  Testslevel(
    id: 7,
    level: 'B2',
    correctIndex: 2,
    text: "If I ___ you, I would apply for that job.",
    options: ["am", "was", "were", "had been"],
    hint: "حالة الشرط الثانية (Second Conditional) للتخيل.",
  ),
  Testslevel(
    id: 8,
    level: 'B2',
    correctIndex: 0,
    text: "The letter ___ yesterday.",
    options: ["was sent", "sent", "has sent", "is sent"],
    hint: "صيغة المبني للمجهول في الماضي (Passive Voice).",
  ),

  
  Testslevel(
    id: 9,
    level: 'C1',
    correctIndex: 3,
    text: "Scarcely ___ the door when the phone rang.",
    options: ["I had opened", "I opened", "did I open", "had I opened"],
    hint: "قاعدة الانعكاس (Inversion) بعد الكلمات السلبية.",
  ),
  Testslevel(
    id: 10,
    level: 'C1',
    correctIndex: 1,
    text: "He is believed ___ the country in secret.",
    options: ["to leave", "to have left", "leaving", "that he left"],
    hint: "استخدام صيغة (Perfect Infinitive) للأحداث الماضية.",
  ),
];
