# Implementation Notes

## Why SM2 Is Separate

Normal, practice, level, and AI review quizzes measure recall for the quiz feature. They do not own spaced-repetition scheduling. The SM2 Review Quiz has separate attempt/item tables and is the only path that updates `user_words` scheduling fields, hard/mastered status, and daily streaks.

## Why Translation Is Separate From AI

Instant Arabic translation is stored in `word_translations` as provider-backed dictionary data. AI output is used for contextual examples and explanations, stored separately in `word_examples` or returned as contextual metadata. This avoids treating an AI explanation as the official translation.

## Daily Word Limit

Words are normalized with trim, lowercase, and collapsed spaces. The global word is saved once in `dictionary_words`; each user gets one `user_words` row. A user can activate 10 new words per UTC day. Extra words are saved as `pending`, not deleted, and pending words are excluded from SM2 until activated.

## Streak Calculation

The daily streak updates only after a valid submitted SM2 Review Quiz. It increases once per calendar day. Multiple completed SM2 quizzes on the same day increment completed quiz count but do not increase the streak again. If the last SM2 quiz date is not yesterday, the next valid submit resets the streak to 1. Abandoned quizzes and normal quizzes never affect streaks.

## Modified SM2

The app uses a modified SM2 algorithm. Quality is inferred from correctness and per-question duration instead of asking the learner to self-grade. A single wrong answer reduces repeats without always resetting them to zero; repeated wrong answers are harsher and can mark the word `hard`. Correct answers increase score, repeats, ease factor, and interval, with intervals capped at 60 days. Mastered words are retained and scheduled farther out instead of being removed.

## Database Reset During Development

This project currently uses SQLAlchemy `Base.metadata.create_all`. SQLite will not reshape existing tables automatically. For a clean local reset, stop the backend, back up `Back-End/vocabgen.db` if needed, remove it, then restart the backend. Production should use Alembic migrations.
