import unittest

import app as deployment_app


class DeploymentApiTest(unittest.TestCase):
    def setUp(self):
        deployment_app.store = deployment_app.MemoryDeploymentStore()
        self.client = deployment_app.app.test_client()

    def test_health(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["status"], "ok")

    def test_create_deployment_validates_required_fields(self):
        response = self.client.post("/deployments", json={"service": "api"})

        self.assertEqual(response.status_code, 400)
        body = response.get_json()
        self.assertEqual(body["error"], "validation_error")
        self.assertEqual(body["fields"]["environment"], "required")

    def test_create_deployment_rejects_unknown_fields(self):
        payload = {
            "service": "api",
            "environment": "prod",
            "version": "2026.05.15",
            "status": "queued",
            "secret": "do-not-store",
        }

        response = self.client.post("/deployments", json=payload)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["fields"]["secret"], "is not allowed")

    def test_create_deployment_and_read_back(self):
        payload = {
            "service": "api",
            "environment": "prod",
            "version": "2026.05.15",
            "status": "succeeded",
            "commit_sha": "abc123",
        }

        created = self.client.post("/deployments", json=payload)
        deployment_id = created.get_json()["deployment"]["id"]
        fetched = self.client.get(f"/deployments/{deployment_id}")

        self.assertEqual(created.status_code, 201)
        self.assertEqual(fetched.status_code, 200)
        self.assertEqual(fetched.get_json()["deployment"]["service"], "api")

    def test_payload_size_limit(self):
        response = self.client.post(
            "/deployments",
            data="x" * (deployment_app.app.config["MAX_CONTENT_LENGTH"] + 1),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 413)


if __name__ == "__main__":
    unittest.main()
