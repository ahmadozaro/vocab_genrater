# AI VocabGen — Project Documentation

---

## 1. Project Overview

AI VocabGen is a full-stack vocabulary builder that helps users learn English vocabulary through:

- **Instant Arabic translation** while typing a word
- **AI-generated context** (definitions, examples, explanations) via Groq
- **Modified SM2 spaced repetition** for review scheduling
- **Quizzes** — standard, AI review, and SM2 review
- **Streak tracking** based on daily SM2 quiz completion
- **Daily word limit** (10 active new words per UTC day)

### Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Backend   | Python 3.12+, FastAPI, SQLAlchemy   |
| Frontend  | Flutter 3.41+, Dart 3.11+           |
| Database  | SQLite (dev), PostgreSQL (prod)     |
| AI        | Groq (llama-3.1-8b-instant)         |
| Email     | SendGrid / Resend / SMTP fallback   |
| Trans.    | deep-translator (demo), replaceable |
| Auth      | JWT (python-jose), bcrypt           |

---

## 2. Final Database / ERD

```
User ──1:N──> Word ──1:N──> Sentence
  │
  ├──1:1──> Progress
  │
  ├──1:N──> Quiz
  │
  ├──1:N──> WordProgress (SM2)
  │
  ├──1:N──> Notification
  │
  └──1:N──> OtpChallenge
```

### Key Constraints

| Table         | Constraint                | Reason                            |
|---------------|---------------------------|-----------------------------------|
| Progress      | `user_id` unique          | One progress row per user         |
| Word          | (user_id, text)           | Per-user unique word text         |
| WordProgress  | (user_id, word_id) unique | One SM2 state per user per word   |

---

## 3. Final Tables

### User
| Column              | Type           | Notes                        |
|---------------------|----------------|------------------------------|
| `id`                | Integer PK     |                              |
| `email`             | String(unique) |                              |
| `name`              | String         |                              |
| `hashed_password`   | String         | bcrypt                       |
| `is_active`         | Boolean        |                              |
| `is_email_verified` | Boolean        |                              |
| `level`             | String?        | beginner / intermediate / advanced |
| `interests`         | String?        | Comma-separated              |
| `created_at`        | DateTime       |                              |

### Word
| Column          | Type         | Notes              |
|-----------------|--------------|--------------------|
| `id`            | Integer PK   |                    |
| `user_id`       | Integer FK   | → User             |
| `text`          | String       |                    |
| `arabic_meaning`| String?      | Instant translation|
| `audio`         | String?      |                    |
| `source`        | String?      |                    |
| `created_at`    | DateTime     |                    |

### Sentence
| Column          | Type     | Notes           |
|-----------------|----------|-----------------|
| `id`            | Integer PK |               |
| `word_id`       | Integer FK | → Word          |
| `text`          | Text     | Example sentence|
| `arabic_meaning`| String?  | Translation     |

### Quiz
| Column         | Type        | Notes                    |
|----------------|-------------|--------------------------|
| `id`           | Integer PK  |                          |
| `user_id`      | Integer FK  | → User                   |
| `score`        | Integer     |                          |
| `total`        | Integer     |                          |
| `answers`      | Text(JSON)  |                          |
| `is_ai_review` | Boolean     | AI-generated quiz flag   |
| `completed_at` | DateTime    |                          |

### Progress
| Column            | Type        | Notes                    |
|-------------------|-------------|--------------------------|
| `id`              | Integer PK  |                          |
| `user_id`         | Integer FK  | → User (unique)          |
| `total_words`     | Integer     |                          |
| `words_learned`   | Integer     |                          |
| `level`           | String?     |                          |
| `streak_days`     | Integer     |                          |
| `last_active_date`| DateTime    |                          |

### WordProgress (SM2)
| Column             | Type        | Notes                 |
|--------------------|-------------|-----------------------|
| `id`               | Integer PK  |                       |
| `user_id`          | Integer FK  | → User                |
| `word_id`          | Integer FK  | → Word                |
| `repetitions`      | Integer     | SM2 repetition count  |
| `interval_days`    | Integer     | Days until next review|
| `easiness_factor`  | Float       | SM2 EF (default 2.5)  |
| `next_review_date` | DateTime    |                       |
| `last_reviewed`    | DateTime?   |                       |
| `score`            | Integer     |                       |

### Notification
| Column       | Type        | Notes     |
|--------------|-------------|-----------|
| `id`         | Integer PK  |           |
| `user_id`    | Integer FK  | → User    |
| `message`    | String      |           |
| `type`       | String      |           |
| `is_read`    | Boolean     |           |
| `created_at` | DateTime    |           |

### OtpChallenge
| Column       | Type        | Notes                              |
|--------------|-------------|------------------------------------|
| `id`         | Integer PK  |                                    |
| `email`      | String      |                                    |
| `purpose`    | String      | login / email_verification / password_reset |
| `code`       | String      | 6-digit code                       |
| `expires_at` | DateTime    | 5-minute TTL                       |
| `used`       | Boolean     |                                    |
| `created_at` | DateTime    |                                    |

---

## 4. SM2 Review Quiz Design

### Flow

1. **Start Quiz** (`POST /sm2/quizzes/start`)
   - Fetches words where `next_review_date <= now` (due)
   - Creates a `Quiz` with `is_ai_review=False`
   - Returns quiz ID + due words

2. **Submit Quiz** (`POST /sm2/quizzes/{id}/submit`)
   - For each answer: retrieves `WordProgress`, applies SM2 algorithm
   - Updates `repetitions`, `interval_days`, `easiness_factor`, `next_review_date`
   - Updates `Progress.total_words` and `words_learned`

3. **Due Summary** (`GET /sm2/due-summary`)
   - Count of words due for review

4. **Abandon** (`POST /sm2/quizzes/{id}/abandon`)
   - Closes quiz without updating SM2 values or streak

### Modified SM2 Algorithm

```
IF quality >= 3 (correct answer):
    IF repetitions == 0:  interval = 1 day
    IF repetitions == 1:  interval = 6 days
    ELSE:                 interval = round(interval_days * easiness_factor)
    repetitions += 1
ELSE (incorrect):
    repetitions = 0
    interval = 1

EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
EF' = max(EF', 1.3)

next_review_date = now + interval_days
```

**Key modifications from standard SM2:**
- Quality is inferred from correctness + response time instead of self-grading
- A single wrong answer reduces repeats without always resetting to zero
- Repeated wrong answers can mark the word `hard`
- Max interval is capped at 60 days
- Skipped/empty answers count harshly (after confirmation dialog)

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/sm2/due-summary` | Count of due words |
| `POST` | `/sm2/quizzes/start` | Create new SM2 quiz |
| `POST` | `/sm2/quizzes/{id}/submit` | Submit answers |
| `POST` | `/sm2/quizzes/{id}/abandon` | Abandon quiz |

### Redesign Proposals

1. **Extract SM2 service** from router into `app/core/sm2.py` as a pure function for testability
2. **Extract `get_or_create_progress`** — currently duplicated in `sm2_quiz_router.py` and `progress_router.py`
3. **Add `quiz_type` enum** (`standard`, `ai_review`, `sm2_review`) instead of `is_ai_review` boolean
4. **Batch score update endpoint** (`PATCH /sm2/words/batch-score`)
5. **Background scheduling** for pre-computing due words for large vocabularies

---

## 5. Translation Design

### Architecture

Translation is handled by `app/services/translation_service.py`.

- Uses `deep-translator` by default (free, no API key)
- Replaceable with Google Cloud Translation by editing the service file — no router changes needed
- Separate from AI service to avoid conflating dictionary data with AI-generated content

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/words/translate-instant?text=...` | Instant Arabic translation |
| `POST` | `/words/lookup` | Full word lookup |

### Data Separation

| Field | Source | Purpose |
|-------|--------|---------|
| `arabic_meaning` | Translation service | Direct dictionary translation |
| `translationAr` | Translation service | Instant translation text |
| `aiMeaningAr` | AI (Groq) | Contextual Arabic explanation |
| `aiDefinitionEn` | AI (Groq) | Simple English definition |
| Sentences | AI (Groq) | Example sentences with translations |

This avoids treating an AI explanation as the official dictionary translation.

---

## 6. AI Service Design

### Architecture

AI features are routed through the backend at `POST /ai/suggest-words` to keep API keys server-side.

### Provider

- **Groq** via `httpx` Python package
- Configured via `GROQ_API_KEY` in `Back-End/.env`
- Model: `llama-3.1-8b-instant`
- Endpoint: `https://api.groq.com/openai/v1/chat/completions`

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/ai/suggest-words` | Suggest words based on level + interests |
| `POST` | `/quizzes/ai-review` | Create AI-generated review quiz |

### Usage

The Flutter app never calls an AI provider directly. All AI requests go through the backend:

- **Suggested words screen** → `POST /ai/suggest-words`
- **AI review quiz** → `POST /quizzes/ai-review`

### Fallback

Every AI feature has a local fallback. If Groq is unavailable:
- Suggested words fall back to a curated list of 24+ words
- Quiz questions are generated deterministically from user's word list
- Word details fall back to simple template text
- No error is shown to the user — fallback data is returned silently

---

## 7. Progress and Streak Rules

### Progress Table

One `Progress` row per user (unique constraint on `user_id`). Updated on:
- Word creation: `total_words` increments
- SM2 quiz submit: `words_learned` increments based on score

### Streak Calculation

- Streak updates **only** after a valid submitted SM2 Review Quiz
- Increases **once per calendar day** (UTC)
- Multiple SM2 quizzes on the same day do **not** increment streak again
- If `last_active_date` is not yesterday → next valid submit resets streak to `1`
- Abandoned quizzes and standard quizzes **never** affect streaks

### Daily Word Limit

- First 10 new words per UTC day become active (enter SM2 rotation)
- Extra words are saved as `pending` — not deleted, just excluded from SM2
- Pending words are automatically activated later when daily capacity becomes available
- Duplicate detection uses `normalizedText` (trim + lowercase + collapsed spaces)

---

## 8. Docker Notes

### Structure

```
vocab_genrater/
├── Dockerfile
├── docker-compose.yml
├── run-docker.ps1
├── .dockerignore
└── AI-VocabGen-main/
    └── Back-End/
        ├── app/
        └── .env
```

### Dockerfile

- Base: `python:3.12-slim`
- Installs `requirements.txt` from `Back-End/`
- Runs: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

### docker-compose.yml

```yaml
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    env_file:
      - AI-VocabGen-main/Back-End/.env
```

### Run

```powershell
docker compose up --build
```

### Notes

- The `.dockerignore` excludes `**/node_modules`, `**/__pycache__`, `**/.git`, etc.
- The container reads env vars from `AI-VocabGen-main/Back-End/.env`

---

## 9. Remaining Warnings / TODOs

### Warnings

- **GROQ_API_KEY** in `Back-End/.env` must never be committed — the root `.gitignore` now covers `.env`
- **SQLite in development**: `Base.metadata.create_all` will not reshape existing tables. Delete `vocabgen.db` if models change:
  ```bash
  rm -f AI-VocabGen-main/Back-End/vocabgen.db
  ```
- **Production should use Alembic** for schema migrations instead of `create_all`
- **Deep-translator** is a demo provider. Replace `translation_service.py` with Google Cloud Translation for production
