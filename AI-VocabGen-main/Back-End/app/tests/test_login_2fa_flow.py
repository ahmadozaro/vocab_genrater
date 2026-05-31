import time
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app


class LoginTwoFactorFlowTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def _email(self, prefix: str) -> str:
        return f"{prefix}_{time.time_ns()}@example.com"

    def _verified_user(self):
        email = self._email("login2fa")
        with patch("app.routers.user_router.is_email_enabled", return_value=False):
            register = self.client.post(
                "/register",
                json={"name": "Login 2FA", "email": email, "password": "secret123"},
            )
            self.assertEqual(register.status_code, 200)
            code = register.json()["verification_debug_code"]
            verify = self.client.post(
                "/auth/verify-email",
                json={"email": email, "code": code},
            )
            self.assertEqual(verify.status_code, 200)
        return email

    def test_login_requires_otp_before_issuing_jwt(self):
        email = self._verified_user()

        with patch("app.routers.user_router.is_email_enabled", return_value=False):
            login = self.client.post(
                "/login",
                data={"username": email, "password": "secret123"},
            )
            self.assertEqual(login.status_code, 200)
            payload = login.json()
            self.assertTrue(payload["requires_2fa"])
            self.assertIn("challenge_id", payload)
            self.assertIn("debug_code", payload)
            self.assertNotIn("access_token", payload)

            verify = self.client.post(
                "/auth/login/verify-otp",
                json={
                    "email": email,
                    "challenge_id": payload["challenge_id"],
                    "code": payload["debug_code"],
                },
            )
            self.assertEqual(verify.status_code, 200)
            self.assertIn("access_token", verify.json())

    def test_login_otp_cannot_be_reused(self):
        email = self._verified_user()

        with patch("app.routers.user_router.is_email_enabled", return_value=False):
            login = self.client.post(
                "/login",
                data={"username": email, "password": "secret123"},
            ).json()
            body = {
                "email": email,
                "challenge_id": login["challenge_id"],
                "code": login["debug_code"],
            }
            first = self.client.post("/auth/login/verify-otp", json=body)
            second = self.client.post("/auth/login/verify-otp", json=body)

        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 400)

    def test_invalid_login_otp_attempts_are_limited(self):
        email = self._verified_user()

        with patch("app.routers.user_router.is_email_enabled", return_value=False):
            login = self.client.post(
                "/login",
                data={"username": email, "password": "secret123"},
            ).json()
            statuses = [
                self.client.post(
                    "/auth/login/verify-otp",
                    json={
                        "email": email,
                        "challenge_id": login["challenge_id"],
                        "code": "000000",
                    },
                ).status_code
                for _ in range(6)
            ]

        self.assertEqual(statuses[:5], [400, 400, 400, 400, 400])
        self.assertEqual(statuses[5], 429)


if __name__ == "__main__":
    unittest.main()
