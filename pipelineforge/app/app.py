from datetime import datetime, timezone
import os
from uuid import uuid4

from flask import Flask, jsonify, request

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError

    STORAGE_EXCEPTIONS = (BotoCoreError, ClientError)
except ImportError:
    boto3 = None
    STORAGE_EXCEPTIONS = (RuntimeError,)


APP_NAME = "pipelineforge-deployment-tracker"
VALID_STATUSES = {"queued", "in_progress", "succeeded", "failed", "rolled_back"}
REQUIRED_DEPLOYMENT_FIELDS = {"service", "environment", "version", "status"}

app = Flask(__name__)


class DeploymentStore:
    def list(self, environment=None, service=None, limit=50):
        raise NotImplementedError

    def get(self, deployment_id):
        raise NotImplementedError

    def create(self, deployment):
        raise NotImplementedError


class MemoryDeploymentStore(DeploymentStore):
    def __init__(self):
        self.deployments = {}

    def list(self, environment=None, service=None, limit=50):
        deployments = sorted(
            self.deployments.values(),
            key=lambda item: item["created_at"],
            reverse=True,
        )
        if environment:
            deployments = [item for item in deployments if item["environment"] == environment]
        if service:
            deployments = [item for item in deployments if item["service"] == service]
        return deployments[:limit]

    def get(self, deployment_id):
        return self.deployments.get(deployment_id)

    def create(self, deployment):
        self.deployments[deployment["id"]] = deployment
        return deployment


class DynamoDeploymentStore(DeploymentStore):
    def __init__(self, table_name):
        if boto3 is None:
            raise RuntimeError("boto3 is required when APP_TABLE_NAME is configured")
        self.table = boto3.resource("dynamodb").Table(table_name)

    def list(self, environment=None, service=None, limit=50):
        scan_kwargs = {"Limit": limit}
        filters = []
        expression_values = {}

        if environment:
            filters.append("environment = :environment")
            expression_values[":environment"] = environment
        if service:
            filters.append("service = :service")
            expression_values[":service"] = service
        if filters:
            scan_kwargs["FilterExpression"] = " AND ".join(filters)
            scan_kwargs["ExpressionAttributeValues"] = expression_values

        response = self.table.scan(**scan_kwargs)
        deployments = response.get("Items", [])
        return sorted(
            deployments,
            key=lambda item: item.get("created_at", ""),
            reverse=True,
        )

    def get(self, deployment_id):
        response = self.table.get_item(Key={"id": deployment_id})
        return response.get("Item")

    def create(self, deployment):
        self.table.put_item(
            Item=deployment,
            ConditionExpression="attribute_not_exists(id)",
        )
        return deployment


def build_store():
    table_name = os.environ.get("APP_TABLE_NAME")
    if table_name:
        return DynamoDeploymentStore(table_name)
    return MemoryDeploymentStore()


store = build_store()


@app.after_request
def add_security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "not_found", "message": "Resource not found"}), 404


@app.errorhandler(500)
def server_error(error):
    return jsonify({"error": "internal_error", "message": "Unexpected server error"}), 500


@app.route("/")
@app.route("/health")
def health():
    return jsonify(
        {
            "service": APP_NAME,
            "status": "ok",
            "storage": "dynamodb" if os.environ.get("APP_TABLE_NAME") else "memory",
        }
    )


@app.route("/deployments", methods=["GET"])
def list_deployments():
    environment = request.args.get("environment")
    service = request.args.get("service")
    limit = parse_limit(request.args.get("limit"))

    try:
        deployments = store.list(environment=environment, service=service, limit=limit)
    except STORAGE_EXCEPTIONS as exc:
        app.logger.exception("Failed to list deployments")
        return jsonify({"error": "storage_error", "message": str(exc)}), 503

    return jsonify({"deployments": deployments})


@app.route("/deployments/<deployment_id>", methods=["GET"])
def get_deployment(deployment_id):
    try:
        deployment = store.get(deployment_id)
    except STORAGE_EXCEPTIONS as exc:
        app.logger.exception("Failed to get deployment")
        return jsonify({"error": "storage_error", "message": str(exc)}), 503

    if not deployment:
        return jsonify({"error": "not_found", "message": "Deployment not found"}), 404
    return jsonify({"deployment": deployment})


@app.route("/deployments", methods=["POST"])
def create_deployment():
    payload = request.get_json(silent=True) or {}
    errors = validate_deployment(payload)
    if errors:
        return jsonify({"error": "validation_error", "fields": errors}), 400

    now = datetime.now(timezone.utc).isoformat()
    deployment = {
        "id": str(uuid4()),
        "service": payload["service"].strip(),
        "environment": payload["environment"].strip(),
        "version": payload["version"].strip(),
        "status": payload["status"].strip(),
        "commit_sha": payload.get("commit_sha", "").strip(),
        "deployed_by": payload.get("deployed_by", "").strip(),
        "notes": payload.get("notes", "").strip(),
        "created_at": now,
        "updated_at": now,
    }

    try:
        store.create(deployment)
    except STORAGE_EXCEPTIONS as exc:
        app.logger.exception("Failed to create deployment")
        return jsonify({"error": "storage_error", "message": str(exc)}), 503

    return jsonify({"deployment": deployment}), 201


def parse_limit(raw_limit):
    if not raw_limit:
        return 50
    try:
        return min(max(int(raw_limit), 1), 100)
    except ValueError:
        return 50


def validate_deployment(payload):
    errors = {}
    missing_fields = REQUIRED_DEPLOYMENT_FIELDS - payload.keys()
    for field in sorted(missing_fields):
        errors[field] = "required"

    for field in REQUIRED_DEPLOYMENT_FIELDS & payload.keys():
        if not isinstance(payload[field], str) or not payload[field].strip():
            errors[field] = "must be a non-empty string"

    status = payload.get("status")
    if isinstance(status, str) and status.strip() not in VALID_STATUSES:
        errors["status"] = f"must be one of: {', '.join(sorted(VALID_STATUSES))}"

    for field in {"commit_sha", "deployed_by", "notes"} & payload.keys():
        if not isinstance(payload[field], str):
            errors[field] = "must be a string"

    return errors


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
