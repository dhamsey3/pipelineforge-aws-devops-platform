#!/bin/bash
# PipelineForge deployment script
set -e

ENVIRONMENT=${1:-dev}
GITHUB_OWNER=${2:?Usage: bash deploy.sh <environment> <github-owner> <github-repo> [github-branch] <github-oauth-token>}
GITHUB_REPO=${3:?Usage: bash deploy.sh <environment> <github-owner> <github-repo> [github-branch] <github-oauth-token>}
if [ -z "${5:-}" ]; then
  GITHUB_BRANCH=main
  GITHUB_TOKEN=${4:?Usage: bash deploy.sh <environment> <github-owner> <github-repo> [github-branch] <github-oauth-token>}
else
  GITHUB_BRANCH=${4}
  GITHUB_TOKEN=${5}
fi

TEMPLATE_BUCKET=${TEMPLATE_BUCKET:?Set TEMPLATE_BUCKET to an existing S3 bucket for packaged nested CloudFormation templates}
PACKAGED_TEMPLATE=${PACKAGED_TEMPLATE:-/tmp/pipelineforge-main-packaged.yml}

aws cloudformation package \
  --template-file ../cloudformation/main.yml \
  --s3-bucket ${TEMPLATE_BUCKET} \
  --output-template-file ${PACKAGED_TEMPLATE}

aws cloudformation deploy \
  --template-file ${PACKAGED_TEMPLATE} \
  --stack-name pipelineforge-main-stack-${ENVIRONMENT} \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=${ENVIRONMENT} \
    GitHubOwner=${GITHUB_OWNER} \
    GitHubRepo=${GITHUB_REPO} \
    GitHubBranch=${GITHUB_BRANCH} \
    GitHubOAuthToken=${GITHUB_TOKEN}

echo "Main stack deployment triggered. Monitor progress in AWS Console."
