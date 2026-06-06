# AI VocabGen

AI-powered vocabulary builder with spaced repetition (SM2), instant Arabic translation, and quiz system.

## Run Backend Normally

```bash
cd AI-VocabGen-main/Back-End
pip install -r requirements.txt
python run_backend.py
```

## Run Frontend Normally

```bash
cd AI-VocabGen-main/Front-End
flutter pub get
flutter run
```

## Run Backend with Docker

### Prerequisites

- Docker Desktop installed and running

### Steps

1. **Add your API key** to `AI-VocabGen-main/Back-End/.env`:

   ```env
   GROQ_API_KEY=your_key_here
   ```

2. **Build and start the container**:

   ```bash
   docker compose up --build
   ```

3. **Open the API docs**:
   [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

### Stop

Press `CTRL+C`, then:

```bash
docker compose down
```

### Notes

- The backend code is mounted as a volume so changes take effect immediately (hot reload).
- The `.env` file stays on your machine and is never copied into the image.
- **Never commit a real API key** — `.env` is ignored by git.

## Environment File

Place `.env` in `AI-VocabGen-main/Back-End/.env` with:

```env
AI_PROVIDER=groq
GROQ_API_KEY=your_key_here
SECRET_KEY=change_me
```

**WARNING:** Never commit a real `GROQ_API_KEY` to version control.
