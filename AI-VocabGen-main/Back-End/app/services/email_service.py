import smtplib
import json
from email.message import EmailMessage
from html import escape
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.core.config import settings


class EmailNotConfiguredError(RuntimeError):
    pass


class EmailDeliveryError(RuntimeError):
    pass


def is_email_enabled() -> bool:
    return is_sendgrid_enabled() or is_resend_enabled() or is_smtp_enabled()


def is_sendgrid_enabled() -> bool:
    return bool(settings.SENDGRID_API_KEY.strip() and settings.SENDGRID_FROM_EMAIL.strip())


def is_resend_enabled() -> bool:
    return bool(settings.RESEND_API_KEY.strip() and settings.RESEND_FROM_EMAIL.strip())


def is_smtp_enabled() -> bool:
    return all(
        [
            settings.SMTP_HOST.strip(),
            settings.SMTP_USERNAME.strip(),
            settings.SMTP_PASSWORD.strip(),
        ]
    )


def send_verification_code(to_email: str, code: str) -> None:
    _send_code_email(
        to_email=to_email,
        subject="Verify your AI VocabGen email",
        title="Verify your email",
        message="Use this code to finish creating your AI VocabGen account.",
        code=code,
    )


def send_password_reset_code(to_email: str, code: str) -> None:
    _send_code_email(
        to_email=to_email,
        subject="Reset your AI VocabGen password",
        title="Reset your password",
        message="Use this code to reset your AI VocabGen password.",
        code=code,
    )


def send_login_otp_code(to_email: str, code: str) -> None:
    _send_code_email(
        to_email=to_email,
        subject="Your AI VocabGen login code",
        title="Confirm your login",
        message="Use this code to complete your AI VocabGen login. It expires in 5 minutes.",
        code=code,
    )


def _send_code_email(
    *,
    to_email: str,
    subject: str,
    title: str,
    message: str,
    code: str,
) -> None:
    if not is_email_enabled():
        raise EmailNotConfiguredError("Email provider is not configured")

    html = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2>{escape(title)}</h2>
        <p>{escape(message)}</p>
        <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">
          {escape(code)}
        </p>
        <p>If you did not request this, you can ignore this email.</p>
      </body>
    </html>
    """
    text = (
        f"{title}\n\n{message}\n\nYour code: {code}\n\n"
        "If you did not request this, you can ignore this email."
    )

    if is_sendgrid_enabled():
        _send_with_sendgrid(
            to_email=to_email,
            subject=subject,
            html=html,
            text=text,
        )
        return

    if is_resend_enabled():
        _send_with_resend(
            to_email=to_email,
            subject=subject,
            html=html,
            text=text,
        )
        return

    from_email = settings.SMTP_FROM_EMAIL.strip() or settings.SMTP_USERNAME.strip()
    from_name = settings.SMTP_FROM_NAME.strip() or "AI VocabGen"

    email = EmailMessage()
    email["Subject"] = subject
    email["From"] = f"{from_name} <{from_email}>"
    email["To"] = to_email
    email.set_content(text)
    email.add_alternative(html, subtype="html")

    try:
        if settings.SMTP_USE_SSL:
            with smtplib.SMTP_SSL(
                settings.SMTP_HOST,
                settings.SMTP_PORT,
                timeout=15,
            ) as server:
                _login_and_send(server, email, from_email, to_email)
        else:
            with smtplib.SMTP(
                settings.SMTP_HOST,
                settings.SMTP_PORT,
                timeout=15,
            ) as server:
                if settings.SMTP_USE_TLS:
                    server.starttls()
                _login_and_send(server, email, from_email, to_email)
    except smtplib.SMTPException as exc:
        raise EmailDeliveryError(f"SMTP delivery failed: {exc}") from exc
    except OSError as exc:
        raise EmailDeliveryError(f"SMTP connection failed: {exc}") from exc


def _login_and_send(
    server: smtplib.SMTP,
    email: EmailMessage,
    from_email: str,
    to_email: str,
) -> None:
    server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
    server.send_message(email, from_addr=from_email, to_addrs=[to_email])


def _send_with_resend(
    *,
    to_email: str,
    subject: str,
    html: str,
    text: str,
) -> None:
    from_name = settings.RESEND_FROM_NAME.strip() or "AI VocabGen"
    from_email = settings.RESEND_FROM_EMAIL.strip()
    payload = {
        "from": f"{from_name} <{from_email}>",
        "to": [to_email],
        "subject": subject,
        "html": html,
        "text": text,
    }
    request = Request(
        "https://api.resend.com/emails",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {settings.RESEND_API_KEY.strip()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=15) as response:
            if response.status < 200 or response.status >= 300:
                raise EmailDeliveryError(
                    f"Resend delivery failed with status {response.status}"
                )
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise EmailDeliveryError(
            f"Resend delivery failed with status {exc.code}: {detail}"
        ) from exc
    except URLError as exc:
        raise EmailDeliveryError(f"Resend connection failed: {exc.reason}") from exc


def _send_with_sendgrid(
    *,
    to_email: str,
    subject: str,
    html: str,
    text: str,
) -> None:
    from_name = settings.SENDGRID_FROM_NAME.strip() or "AI VocabGen"
    from_email = settings.SENDGRID_FROM_EMAIL.strip()
    payload = {
        "personalizations": [
            {
                "to": [{"email": to_email}],
                "subject": subject,
            }
        ],
        "from": {"email": from_email, "name": from_name},
        "content": [
            {"type": "text/plain", "value": text},
            {"type": "text/html", "value": html},
        ],
    }
    request = Request(
        "https://api.sendgrid.com/v3/mail/send",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {settings.SENDGRID_API_KEY.strip()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=15) as response:
            if response.status < 200 or response.status >= 300:
                raise EmailDeliveryError(
                    f"SendGrid delivery failed with status {response.status}"
                )
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise EmailDeliveryError(
            f"SendGrid delivery failed with status {exc.code}: {detail}"
        ) from exc
    except URLError as exc:
        raise EmailDeliveryError(f"SendGrid connection failed: {exc.reason}") from exc
