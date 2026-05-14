# PipelineForge Deployment Tracker API

PipelineForge runs a small Flask API that records deployment events for services and environments. In AWS it persists records to DynamoDB through `APP_TABLE_NAME`; locally it falls back to in-memory storage.

## Endpoints

- `GET /health` - Service health, storage mode, and app identity.
- `GET /deployments` - List recent deployments. Optional filters: `environment`, `service`, `limit`.
- `GET /deployments/{id}` - Fetch one deployment record.
- `POST /deployments` - Create a deployment record.

## Deployment Record

Required fields:

- `service`
- `environment`
- `version`
- `status`

Allowed status values: `queued`, `in_progress`, `succeeded`, `failed`, `rolled_back`.

Optional fields:

- `commit_sha`
- `deployed_by`
- `notes`

Example:

```bash
curl -X POST http://localhost:5000/deployments \
  -H 'Content-Type: application/json' \
  -d '{
    "service": "billing-api",
    "environment": "prod",
    "version": "2026.05.14-1",
    "status": "succeeded",
    "commit_sha": "abc1234",
    "deployed_by": "platform-team"
  }'
```

## Local Development

```bash
pip install -r requirements.txt
python app.py
```

## Container Build

```bash
docker build -t pipelineforge-app .
docker run -p 5000:5000 pipelineforge-app
```
