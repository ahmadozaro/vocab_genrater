# Tables Audit

The final SQLAlchemy model import path creates 13 tables only:

- users
- interests
- user_interests
- dictionary_words
- word_translations
- word_examples
- user_words
- normal_quiz_attempts
- normal_quiz_items
- sm2_quiz_attempts
- sm2_quiz_items
- progress
- notifications

Deleted from the model import path:

- words
- sentences
- quizzes
- questions
- quiz_words
- legacy_quiz_words
- legacy_sentences
- sm2_quizzes

Important: the old SQLite file was removed from this package. If your local copy still has `Back-End/vocabgen.db`, delete it before running the backend.
