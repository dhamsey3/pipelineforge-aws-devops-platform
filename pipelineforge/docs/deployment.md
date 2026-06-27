# PipelineForge Deployment Guide

## Prerequisites

- AWS CLI configured with credentials for the target account
- IAM permissions for CloudFormation, IAM, S3, ECR, ECS, CodeBuild, CodePipeline, SNS, DynamoDB, CodeArtifact, CloudWatch, and VPC resources
- Docker installed for local image builds
- A GitHub repository you can authorize through AWS CodeConnections
- Optional ACM certificate ARN for HTTPS on the public Application Load Balancer

## Connect AWS

Configure AWS credentials outside this repository. For a named local profile:

```bash
aws configure --profile pipelineforge-dev
export AWS_PROFILE=pipelineforge-dev
export AWS_REGION=us-east-1
export AWS_STS_REGIONAL_ENDPOINTS=regional
```

Validate the connection and create the private S3 bucket used for packaged nested CloudFormation templates:

```bash
cd pipelineforge
bash scripts/aws-connect.sh dev
set -a && source .aws-connection.env && set +a
```

The generated `.aws-connection.env` file contains only local connection settings such as account ID, region, profile, and template bucket. It must not contain AWS secret keys.

## Deploy Infrastructure

```bash
cd pipelineforge
bash scripts/deploy.sh dev <github-owner> <github-repo> main
```

The script packages nested CloudFormation templates to `TEMPLATE_BUCKET`, then deploys `cloudformation/main.yml`, which orchestrates the shared platform stacks for networking, IAM, DynamoDB, ECR, CodeArtifact, CodeBuild, CodePipeline, and monitoring. The pipeline deploy stage then creates or updates the ECS application stack after the container image has been built and pushed.

Set `CERTIFICATE_ARN` before running `scripts/deploy.sh` if you want the application load balancer to serve HTTPS and redirect HTTP traffic to HTTPS.

## Authorize GitHub Connection

CloudFormation creates an AWS CodeConnections GitHub connection named `<environment>-pipelineforge-github`. New connections are created in `PENDING` status and must be authorized once in the AWS Console.

After the main stack deploys:

1. Open the AWS Console in the deployment region.
2. Go to **Developer Tools** > **Settings** > **Connections**.
3. Select `<environment>-pipelineforge-github`.
4. Click **Update pending connection**.
5. Authorize/install the GitHub app for the repository.

When the connection status is `AVAILABLE`, start or retry the pipeline execution.

## Application Configuration

The ECS task receives `APP_TABLE_NAME` from CloudFormation and uses it to write deployment records to DynamoDB. If the variable is not set, the app uses in-memory storage for local development only.

## Pipeline Flow

1. CodePipeline pulls source from GitHub through AWS CodeConnections.
2. CodeBuild installs dependencies, builds the Docker image, and pushes commit-tagged and `latest` images to ECR.
3. CodePipeline updates the ECS stack with the application template.
4. ECS runs the Deployment Tracker API in private subnets behind an internet-facing Application Load Balancer.

## Monitor

- Use CloudFormation events for stack progress.
- Use CodePipeline and CodeBuild for source/build/deploy status.
- Use ECS service events and `/ecs/<environment>-pipelineforge-app` CloudWatch Logs for runtime debugging.
- CloudWatch alarms publish pipeline and ECS service failures to the deployment SNS topic.

## Cleanup

The DynamoDB table and pipeline artifact bucket are retained by default to prevent accidental data loss. Disable DynamoDB deletion protection first if you intentionally want to remove the table.

```bash
aws cloudformation delete-stack \
  --stack-name pipelineforge-main-stack-dev \
  --region eu-central-1 \
  --profile pipelineforge-dev
```
