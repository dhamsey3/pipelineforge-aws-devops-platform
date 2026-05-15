# PipelineForge Deployment Guide

## Prerequisites

- AWS CLI configured
- IAM permissions for CloudFormation, IAM, S3, ECR, ECS, CodeBuild, CodePipeline, SNS, DynamoDB, CodeArtifact, CloudWatch, and VPC resources
- Docker installed for local image builds
- A GitHub repository and OAuth token for CodePipeline source access
- Optional ACM certificate ARN for HTTPS on the public Application Load Balancer

## Deploy Infrastructure

```bash
cd scripts
TEMPLATE_BUCKET=<existing-template-bucket> \
  bash deploy.sh dev <github-owner> <github-repo> main <github-oauth-token>
```

The script packages nested CloudFormation templates to `TEMPLATE_BUCKET`, then deploys `cloudformation/main.yml`, which orchestrates the shared platform stacks for networking, IAM, DynamoDB, ECR, CodeArtifact, CodeBuild, CodePipeline, and monitoring. The pipeline deploy stage then creates or updates the ECS application stack after the container image has been built and pushed.

Pass `CertificateArn` when deploying the main stack if you want the application load balancer to serve HTTPS and redirect HTTP traffic to HTTPS.

## Application Configuration

The ECS task receives `APP_TABLE_NAME` from CloudFormation and uses it to write deployment records to DynamoDB. If the variable is not set, the app uses in-memory storage for local development only.

## Pipeline Flow

1. CodePipeline pulls source from GitHub.
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
aws cloudformation delete-stack --stack-name pipelineforge-main-stack-dev
```
