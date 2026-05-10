# PipelineForge Deployment Guide

## Prerequisites
- AWS CLI configured
- IAM permissions for CloudFormation, ECR, ECS, CodeBuild, CodePipeline, SNS, DynamoDB, CodeArtifact
- Docker installed (for local builds)
- GitHub repo and token for pipeline integration

## Deploy Infrastructure
```bash
cd scripts
bash deploy.sh dev
```

## Configure GitHub & Pipeline
- Update `cloudformation/codepipeline.yml` with your GitHub repo and token.
- Push code to trigger pipeline.

## Monitor
- Use AWS Console for CloudFormation, CodePipeline, ECS, and CloudWatch.
- SNS notifications will be sent on deployment events.

## Cleanup
```bash
aws cloudformation delete-stack --stack-name pipelineforge-main-stack-dev
```
