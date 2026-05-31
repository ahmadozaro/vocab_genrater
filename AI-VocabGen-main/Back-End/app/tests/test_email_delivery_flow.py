import json
import time
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app


class EmailDeliveryFlowTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def _email(self, prefix: str) -> str:
        return f"{prefix}_{time.time_ns()}@example.com"

    def test_development_mode_returns_debug_codes(self):
        email = self._email("devmail")

        with patch("app.routers.user_router.is_email_enabled", return_value=False):
            register = self.client.post(
                "/register",
                json={
                    "name": "Dev Mail",
                    "email": email,
                    "password": "secret123",
                },
            )
            self.assertEqual(register.status_code, 200)
            self.assertIn("verification_debug_code", register.json())

            forgot = self.client.post("/auth/forgot-password", json={"email": email})
            self.assertEqual(forgot.status_code, 200)
            self.assertIn("debug_code", forgot.json())

    def test_smtp_mode_sends_email_without_returning_debug_codes(self):
        email = self._email("smtpmail")
        sent_codes = []

        def fake_send(to_email: str, code: str) -> None:
            sent_codes.append((to_email, code))

        with (
            patch("app.routers.user_router.is_email_enabled", return_value=True),
            patch(
                "app.routers.user_router.send_verification_code",
                side_effect=fake_send,
            ),
            patch(
                "app.routers.user_router.send_password_reset_code",
                side_effect=fake_send,
            ),
        ):
            register = self.client.post(
                "/register",
                json={
                    "name": "SMTP Mail",
                    "email": email,
                    "password": "secret123",
                },
            )
            self.assertEqual(register.status_code, 200)
            self.assertNotIn("verification_debug_code", register.json())
            self.assertEqual(len(sent_codes), 1)

            resend = self.client.post(
                "/auth/resend-verification",
                json={"email": email},
            )
            self.assertEqual(resend.status_code, 200)
            self.assertNotIn("debug_code", resend.json())
            self.assertEqual(len(sent_codes), 2)

            forgot = self.client.post("/auth/forgot-password", json={"email": email})
            self.assertEqual(forgot.status_code, 200)
            self.assertNotIn("debug_code", forgot.json())
            self.assertEqual(len(sent_codes), 3)

    def test_resend_mode_uses_http_api(self):
        from app.services import email_service

        captured = {}

        class FakeResponse:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

        def fake_urlopen(request, timeout):
            captured["timeout"] = timeout
            captured["url"] = request.full_url
            captured["headers"] = dict(request.header_items())
            captured["payload"] = json.loads(request.data.decode("utf-8"))
            return FakeResponse()

        with (
            patch.object(email_service.settings, "RESEND_API_KEY", "re_test"),
            patch.object(
                email_service.settings,
                "RESEND_FROM_EMAIL",
                "onboarding@resend.dev",
            ),
            patch.object(email_service.settings, "SMTP_HOST", ""),
            patch("app.services.email_service.urlopen", side_effect=fake_urlopen),
        ):
            email_service.send_verification_code("user@example.com", "123456")

        self.assertEqual(captured["url"], "https://api.resend.com/emails")
        self.assertEqual(captured["timeout"], 15)
        self.assertEqual(captured["payload"]["to"], ["user@example.com"])
        self.assertEqual(captured["payload"]["subject"], "Verify your AI VocabGen email")
        self.assertIn("123456", captured["payload"]["text"])

    def test_sendgrid_mode_uses_http_api(self):
        from app.services import email_service

        captured = {}

        class FakeResponse:
            status = 202

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

        def fake_urlopen(request, timeout):
            captured["timeout"] = timeout
            captured["url"] = request.full_url
            captured["headers"] = dict(request.header_items())
            captured["payload"] = json.loads(request.data.decode("utf-8"))
            return FakeResponse()

        with (
            patch.object(email_service.settings, "SENDGRID_API_KEY", "SG.test"),
            patch.object(
                email_service.settings,
                "SENDGRID_FROM_EMAIL",
                "AI-VocabGen@myapp.com",
            ),
            patch("app.services.email_service.urlopen", side_effect=fake_urlopen),
        ):
            email_service.send_login_otp_code("user@example.com", "654321")

        self.assertEqual(captured["url"], "https://api.sendgrid.com/v3/mail/send")
        self.assertEqual(captured["timeout"], 15)
        self.assertEqual(
            captured["payload"]["personalizations"][0]["to"][0]["email"],
            "user@example.com",
        )
        self.assertEqual(
            captured["payload"]["personalizations"][0]["subject"],
            "Your AI VocabGen login code",
        )
        self.assertIn("654321", captured["payload"]["content"][0]["value"])


if __name__ == "__main__":
    unittest.main()
