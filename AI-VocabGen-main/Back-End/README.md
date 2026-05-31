# AI VocabGen Back-End

FastAPI backend for AI VocabGen.

## Run

```bash
pip install -r requirements.txt
python run_backend.py
```

## Email verification setup

The recommended production option for login 2FA and password reset codes is
SendGrid:

```env
SENDGRID_API_KEY=SG.xxxxxxxxx
SENDGRID_FROM_EMAIL=AI-VocabGen@myapp.com
SENDGRID_FROM_NAME=AI VocabGen
```

Verify the sender or domain in SendGrid before using it. The login flow creates
a 6-digit code that expires after 5 minutes, limits invalid attempts, limits
resends, and issues the JWT only after OTP verification.

Resend is also supported:

```env
RESEND_API_KEY=re_xxxxxxxxx
RESEND_FROM_EMAIL=onboarding@resend.dev
RESEND_FROM_NAME=AI VocabGen
```

For production, verify your own domain in Resend and use an address from that
domain in `RESEND_FROM_EMAIL`.

SMTP is still supported as a fallback:

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM_EMAIL=your_email@gmail.com
SMTP_FROM_NAME=AI VocabGen
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

For Gmail, use an App Password, not your normal account password. If SMTP is not
configured and Resend is not configured, the API stays in development mode and
returns `debug_code` in the response instead of sending an email.

## Main endpoints

### Words and translation

- `POST /translate/instant`
- `POST /words/lookup`
- `POST /words`
- `GET /words`

### SM2 Review Quiz

- `GET /sm2/due`
- `POST /sm2/quizzes/start`
- `POST /sm2/quizzes/{quiz_id}/submit`
- `POST /sm2/quizzes/{quiz_id}/abandon`

### Progress

- `GET /progress/me`
- `POST /progress/update`

## Development database note

If you had an old `vocabgen.db`, delete it before first run because the models were changed:

```bash
rm -f vocabgen.db
```
