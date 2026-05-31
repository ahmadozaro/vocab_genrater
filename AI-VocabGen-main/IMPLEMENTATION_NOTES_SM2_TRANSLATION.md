# AI VocabGen - SM2 + Translation Update

## What changed

### 1. Independent SM2 Review Quiz
The old quizzes are kept separate. SM2 scheduling is now handled only by the new independent SM2 Review Quiz endpoints:

- `GET /sm2/due`
- `POST /sm2/quizzes/start`
- `POST /sm2/quizzes/{quiz_id}/submit`
- `POST /sm2/quizzes/{quiz_id}/abandon`

Exiting/abandoning an SM2 quiz does not update SM2 values or the daily streak.

### 2. Modified SM2 Algorithm
The SM2 algorithm was rewritten in:

- `Back-End/app/services/sm2_service.py`

Rules implemented:

- Correctness + response time determines difficulty.
- Skipped or empty answers count harshly after confirmation.
- One wrong answer does not always reset `sm2Repeats` to zero.
- Repeated wrong answers can reset the word or mark it as `hard`.
- Mastered words are not removed; they are reviewed after longer intervals.
- Max interval is capped at 60 days.

### 3. Daily streak
Daily streak now depends on completing the SM2 Review Quiz, not old quizzes.

Rules:

- Streak increases once per day only.
- Completing more than one SM2 quiz on the same day does not increase the streak again.
- If the user skips a day, the streak resets on the next completed SM2 quiz.

### 4. Daily new words limit
The app now limits active new words to 10 per day.

Rules:

- First 10 words become active and enter SM2.
- Extra words are saved as `pending`.
- Pending words are not deleted.
- Pending words are automatically activated later when daily capacity is available.
- Duplicate words are blocked using `normalizedText`.

### 5. Instant translation + AI explanation
A new translation layer was added:

- `Back-End/app/services/translation_service.py`
- `POST /translate/instant`

The backend now separates:

- `translationAr`: instant translation from translation service.
- `aiMeaningAr`: contextual Arabic explanation from AI.
- `aiDefinitionEn`: simple English definition from AI.
- AI examples are stored as sentences.

This avoids conflicts between direct translation and AI contextual meaning.

### 6. Frontend AI calls fixed
The Flutter suggested words screen no longer calls Anthropic directly. It now calls the backend endpoint:

- `POST /ai/suggest-words`

This keeps API keys and AI providers inside the backend.

## Important database note
Because the SQLAlchemy models changed significantly, delete the old local SQLite database before running the updated backend during development:

```bash
cd Back-End
rm -f vocabgen.db
python run_backend.py
```

For production, use Alembic migrations instead of deleting the database.

## Backend run

```bash
cd Back-End
pip install -r requirements.txt
python run_backend.py
```

## Required environment

Copy `.env.example` to `.env` and add your Gemini key if AI features are needed:

```bash
GEMINI_API_KEY=your_key_here
```

The translation service uses `deep-translator` for demo. It can later be replaced with Google Cloud Translation inside `translation_service.py` without changing routers.
