#!/bin/bash
# PipelineForge deployment script.
set -euo pipefail

ENVIRONMENT=${1:-dev}
GITHUB_OWNER=${2:?Usage: bash deploy.sh <environment> <github-owner> <github-repo> [github-branch]}
GITHUB_REPO=${3:?Usage: bash deploy.sh <environment> <github-owner> <github-repo> [github-branch]}
GITHUB_BRANCH=${4:-main}

TEMPLATE_BUCKET=${TEMPLATE_BUCKET:?Set TEMPLATE_BUCKET to an existing S3 bucket for packaged nested CloudFormation templates}
PACKAGED_TEMPLATE=${PACKAGED_TEMPLATE:-/tmp/pipelineforge-main-packaged.yml}
AWS_PROFILE=${AWS_PROFILE:-}
CERTIFICATE_ARN=${CERTIFICATE_ARN:-}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
LOCAL_AWS_BIN="${REPO_ROOT}/.tools/aws-cli-v2/aws-cli/aws"
AWS_BIN=${AWS_BIN:-aws}
if [ -x "${LOCAL_AWS_BIN}" ] && [ "${AWS_BIN}" = "aws" ]; then
  AWS_BIN="${LOCAL_AWS_BIN}"
fi

CONFIGURED_REGION="$("${AWS_BIN}" configure get region 2>/dev/null || true)"
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-${CONFIGURED_REGION:-us-east-1}}}
export AWS_STS_REGIONAL_ENDPOINTS=${AWS_STS_REGIONAL_ENDPOINTS:-regional}
AWS_ARGS=(--region "${AWS_REGION}")
if [ -n "${AWS_PROFILE}" ]; then
  AWS_ARGS+=(--profile "${AWS_PROFILE}")
fi

PARAMETER_OVERRIDES=(
  "EnvironmentName=${ENVIRONMENT}"
  "GitHubOwner=${GITHUB_OWNER}"
  "GitHubRepo=${GITHUB_REPO}"
  "GitHubBranch=${GITHUB_BRANCH}"
)

if [ -n "${CERTIFICATE_ARN}" ]; then
  PARAMETER_OVERRIDES+=("CertificateArn=${CERTIFICATE_ARN}")
fi

"${AWS_BIN}" "${AWS_ARGS[@]}" cloudformation package \
  --template-file "${PROJECT_ROOT}/cloudformation/main.yml" \
  --s3-bucket "${TEMPLATE_BUCKET}" \
  --output-template-file "${PACKAGED_TEMPLATE}"

"${AWS_BIN}" "${AWS_ARGS[@]}" cloudformation deploy \
  --template-file "${PACKAGED_TEMPLATE}" \
  --stack-name "pipelineforge-main-stack-${ENVIRONMENT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "${PARAMETER_OVERRIDES[@]}"

echo "Main stack deployment triggered. Monitor progress in AWS Console."
