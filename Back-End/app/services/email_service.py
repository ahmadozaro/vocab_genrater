import logging

import smtplib

from email.message import EmailMessage

from html import escape



from app.core.config import settings



logger = logging.getLogger(__name__)





class EmailNotConfiguredError(RuntimeError):

    pass





class EmailDeliveryError(RuntimeError):

    pass





def is_email_enabled() -> bool:

    return is_smtp_enabled()





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



    from_email = settings.SMTP_FROM_EMAIL.strip() or settings.SMTP_USERNAME.strip()

    from_name = settings.SMTP_FROM_NAME.strip() or settings.APP_NAME



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

                server.set_debuglevel(0)

                if settings.SMTP_USE_TLS:

                    server.starttls()

                _login_and_send(server, email, from_email, to_email)

    except smtplib.SMTPAuthenticationError:

        logger.error(

            "SMTP auth failed for host=%s port=%s user=%s",

            settings.SMTP_HOST, settings.SMTP_PORT, settings.SMTP_USERNAME,

        )

        raise EmailDeliveryError("SMTP authentication failed — check SMTP_USERNAME and SMTP_PASSWORD") from None

    except smtplib.SMTPException as exc:

        logger.error(

            "SMTP delivery failed for host=%s port=%s user=%s: %s",

            settings.SMTP_HOST, settings.SMTP_PORT, settings.SMTP_USERNAME, exc,

        )

        raise EmailDeliveryError(f"SMTP delivery failed: {exc}") from exc

    except OSError as exc:

        logger.error(

            "SMTP connection failed for host=%s port=%s user=%s: %s",

            settings.SMTP_HOST, settings.SMTP_PORT, settings.SMTP_USERNAME, exc,

        )

        raise EmailDeliveryError(f"SMTP connection failed: {exc}") from exc





def _login_and_send(

    server: smtplib.SMTP,

    email: EmailMessage,

    from_email: str,

    to_email: str,

) -> None:

    server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)

    server.send_message(email, from_addr=from_email, to_addrs=[to_email])







