# AI VocabGen Clean ERD + SM2 Redesign

This redesign keeps the old normal quizzes and adds a third independent quiz type: **SM2 Review Quiz**. The old duplicated tables were removed from the model import path, and the database must be recreated cleanly.

## Final tables only

The backend should create only these tables:

1. `users`
2. `interests`
3. `user_interests`
4. `dictionary_words`
5. `word_translations`
6. `word_examples`
7. `user_words`
8. `normal_quiz_attempts`
9. `normal_quiz_items`
10. `sm2_quiz_attempts`
11. `sm2_quiz_items`
12. `progress`
13. `notifications`

Removed/deprecated tables that must not exist in a fresh database:

- `words`
- `sentences`
- `quizzes`
- `questions`
- `quiz_words`
- `legacy_quiz_words`
- `legacy_sentences`
- `sm2_quizzes`

## Table summary

### users
- id PK
- name
- email UNIQUE
- password_hash
- reset_code
- level
- created_at
- updated_at

### dictionary_words
Global word data shared by all users.
- id PK
- text
- normalized_text UNIQUE
- definition_en
- created_at

### word_translations
Arabic meaning from the instant translation service.
- id PK
- word_id FK -> dictionary_words.id
- translation_text
- provider
- is_primary
- created_at

### word_examples
Example sentence saved with the word.
- id PK
- word_id FK -> dictionary_words.id
- sentence_en
- sentence_ar
- created_at

### user_words
User-specific learning and SM2 state.
- id PK
- user_id FK -> users.id
- word_id FK -> dictionary_words.id
- status: pending, new, learning, review, hard, mastered
- activation_date
- added_at
- score
- sm2_repeats
- sm2_ease_factor
- sm2_interval_days
- next_review_at
- last_reviewed_at
- correct_streak
- wrong_streak

Unique: `(user_id, word_id)`.

### normal_quiz_attempts
Old/normal quizzes remain here and do not update SM2.
- id PK
- user_id FK -> users.id
- quiz_type
- score
- total_questions
- started_at
- submitted_at
- status

### normal_quiz_items
Optional details for normal quizzes.
- id PK
- attempt_id FK -> normal_quiz_attempts.id
- user_word_id FK -> user_words.id
- question_text
- correct_answer
- options_json
- user_answer
- is_correct
- created_at

### sm2_quiz_attempts
Third independent quiz type.
- id PK
- user_id FK -> users.id
- score
- total_questions
- started_at
- submitted_at
- status
- counts_for_streak

### sm2_quiz_items
Question rows for the SM2 Review Quiz.
- id PK
- attempt_id FK -> sm2_quiz_attempts.id
- user_word_id FK -> user_words.id
- question_text
- question_type
- correct_answer
- options_json
- user_answer
- is_correct
- duration_seconds
- quality
- created_at

The correct answer is not sent to Flutter when starting a quiz. It stays backend-side for submit validation.

### progress
- id PK
- user_id FK -> users.id UNIQUE
- daily_streak
- last_sm2_quiz_date
- completed_sm2_quizzes
- updated_at

Counts such as active words, mastered words, and due reviews are calculated dynamically from `user_words`, not stored redundantly.

### interests
- id PK
- name
- created_at

### user_interests
- user_id FK -> users.id
- interest_id FK -> interests.id

### notifications
- id PK
- user_id FK -> users.id
- message
- is_read
- created_at

## Mermaid ERD

```mermaid
erDiagram
    users ||--o{ user_words : owns
    users ||--o{ normal_quiz_attempts : takes
    users ||--o{ sm2_quiz_attempts : takes
    users ||--|| progress : has
    users ||--o{ notifications : receives
    users }o--o{ interests : selects

    dictionary_words ||--o{ word_translations : has
    dictionary_words ||--o{ word_examples : has
    dictionary_words ||--o{ user_words : learned_as

    user_words ||--o{ normal_quiz_items : used_in
    user_words ||--o{ sm2_quiz_items : reviewed_in

    normal_quiz_attempts ||--o{ normal_quiz_items : contains
    sm2_quiz_attempts ||--o{ sm2_quiz_items : contains

    users {
        int id PK
        string name
        string email UK
        string password_hash
        string reset_code
        string level
        datetime created_at
        datetime updated_at
    }

    dictionary_words {
        int id PK
        string text
        string normalized_text UK
        text definition_en
        datetime created_at
    }

    word_translations {
        int id PK
        int word_id FK
        string translation_text
        string provider
        int is_primary
        datetime created_at
    }

    word_examples {
        int id PK
        int word_id FK
        text sentence_en
        text sentence_ar
        datetime created_at
    }

    user_words {
        int id PK
        int user_id FK
        int word_id FK
        string status
        datetime activation_date
        datetime added_at
        int score
        int sm2_repeats
        float sm2_ease_factor
        int sm2_interval_days
        datetime next_review_at
        datetime last_reviewed_at
        int correct_streak
        int wrong_streak
    }

    normal_quiz_attempts {
        int id PK
        int user_id FK
        string quiz_type
        int score
        int total_questions
        datetime started_at
        datetime submitted_at
        string status
    }

    normal_quiz_items {
        int id PK
        int attempt_id FK
        int user_word_id FK
        text question_text
        string correct_answer
        text options_json
        string user_answer
        bool is_correct
        datetime created_at
    }

    sm2_quiz_attempts {
        int id PK
        int user_id FK
        int score
        int total_questions
        datetime started_at
        datetime submitted_at
        string status
        bool counts_for_streak
    }

    sm2_quiz_items {
        int id PK
        int attempt_id FK
        int user_word_id FK
        text question_text
        string question_type
        string correct_answer
        text options_json
        string user_answer
        bool is_correct
        int duration_seconds
        int quality
        datetime created_at
    }

    progress {
        int id PK
        int user_id FK
        int daily_streak
        date last_sm2_quiz_date
        int completed_sm2_quizzes
        datetime updated_at
    }

    notifications {
        int id PK
        int user_id FK
        string message
        bool is_read
        datetime created_at
    }
```
