#!/bin/bash
# PipelineForge deployment script
set -e

ENVIRONMENT=${1:-dev}

aws cloudformation deploy \
  --template-file ../cloudformation/main.yml \
  --stack-name pipelineforge-main-stack-${ENVIRONMENT} \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides EnvironmentName=${ENVIRONMENT}

echo "Main stack deployment triggered. Monitor progress in AWS Console."
