# PipelineForge Sample App

A minimal Flask REST API for demonstration. Integrates with DynamoDB in production.

## Endpoints
- `GET /` — Health check
- `GET /items` — List items (placeholder)
- `POST /items` — Create item (placeholder)

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
