# PipelineForge

PipelineForge is an AWS-native deployment tracker API. It records deployment events by service and environment, stores them in DynamoDB, and runs as a Flask/Gunicorn container on ECS Fargate behind an Application Load Balancer.

## AWS Status

The AWS `dev` environment has been cleaned up to avoid ongoing infrastructure cost. Redeploy with the commands below when you need the hosted API again.

## API

```bash
# List deployment events
curl http://<app-url>/deployments

# Filter deployment events
curl "http://<app-url>/deployments?environment=dev&service=billing-api"

# Create a deployment event
curl -X POST http://<app-url>/deployments \
  -H "Content-Type: application/json" \
  -d '{"service":"billing-api","environment":"dev","version":"1.0.0","status":"succeeded","commit_sha":"abc1234","deployed_by":"platform-team"}'
```

Core endpoints:

- `GET /health`
- `GET /deployments`
- `GET /deployments?environment=<env>&service=<service>`
- `GET /deployments/{id}`
- `POST /deployments`

## Architecture

- ECS Fargate runs the Deployment Tracker API in private subnets.
- An internet-facing ALB exposes HTTP traffic on port 80 and forwards to the app on port 5000.
- DynamoDB stores deployment records.
- ECR stores the app image.
- CodePipeline, CodeBuild, and CodeConnections provide the GitHub-based CI/CD path.
- CloudWatch Logs, alarms, and SNS support basic observability.

## Repository Structure

- `app/` - Flask Deployment Tracker API
- `cloudformation/` - CloudFormation templates
- `scripts/` - AWS setup and deployment scripts
- `docs/` - Deployment notes
- `buildspec.yml` - CodeBuild build and image-push steps

## Deploy

```bash
cd pipelineforge
export AWS_PROFILE=pipelineforge-dev
export AWS_REGION=eu-central-1
bash scripts/aws-connect.sh dev
set -a && source .aws-connection.env && set +a
bash scripts/deploy.sh dev dhamsey3 pipelineforge-aws-devops-platform main
```

The GitHub connection is managed through AWS CodeConnections. If recreating the stack, authorize `dev-pipelineforge-github` in AWS Console under **CodePipeline > Settings > Connections**.

See `docs/deployment.md` for the full deployment guide.
