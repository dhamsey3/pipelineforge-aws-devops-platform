#!/bin/bash
# Validate AWS credentials and prepare the S3 bucket used for packaged templates.
set -euo pipefail

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
AWS_PROFILE=${AWS_PROFILE:-}
LOCAL_AWS_BIN="${REPO_ROOT}/.tools/aws-cli-v2/aws-cli/aws"
AWS_BIN=${AWS_BIN:-aws}

if [ -x "${LOCAL_AWS_BIN}" ] && [ "${AWS_BIN}" = "aws" ]; then
  AWS_BIN="${LOCAL_AWS_BIN}"
fi

if ! command -v "${AWS_BIN}" >/dev/null 2>&1; then
  echo "AWS CLI is not installed. Install and configure it before continuing." >&2
  exit 1
fi

CONFIGURED_REGION="$("${AWS_BIN}" configure get region 2>/dev/null || true)"
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-${CONFIGURED_REGION:-us-east-1}}}
export AWS_STS_REGIONAL_ENDPOINTS=${AWS_STS_REGIONAL_ENDPOINTS:-regional}

AWS_ARGS=(--region "${AWS_REGION}")
if [ -n "${AWS_PROFILE}" ]; then
  AWS_ARGS+=(--profile "${AWS_PROFILE}")
fi

echo "Checking AWS identity..."
ACCOUNT_ID="$("${AWS_BIN}" "${AWS_ARGS[@]}" sts get-caller-identity --query Account --output text)"
CALLER_ARN="$("${AWS_BIN}" "${AWS_ARGS[@]}" sts get-caller-identity --query Arn --output text)"

TEMPLATE_BUCKET=${TEMPLATE_BUCKET:-pipelineforge-templates-${ACCOUNT_ID}-${AWS_REGION}}

echo "Using AWS account: ${ACCOUNT_ID}"
echo "Using caller: ${CALLER_ARN}"
echo "Using region: ${AWS_REGION}"
echo "Using template bucket: ${TEMPLATE_BUCKET}"

if "${AWS_BIN}" "${AWS_ARGS[@]}" s3api head-bucket --bucket "${TEMPLATE_BUCKET}" >/dev/null 2>&1; then
  echo "Template bucket already exists."
else
  echo "Creating template bucket..."
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    "${AWS_BIN}" "${AWS_ARGS[@]}" s3api create-bucket --bucket "${TEMPLATE_BUCKET}" >/dev/null
  else
    "${AWS_BIN}" "${AWS_ARGS[@]}" s3api create-bucket \
      --bucket "${TEMPLATE_BUCKET}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
  fi
fi

echo "Hardening template bucket..."
"${AWS_BIN}" "${AWS_ARGS[@]}" s3api put-public-access-block \
  --bucket "${TEMPLATE_BUCKET}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

"${AWS_BIN}" "${AWS_ARGS[@]}" s3api put-bucket-encryption \
  --bucket "${TEMPLATE_BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

"${AWS_BIN}" "${AWS_ARGS[@]}" s3api put-bucket-versioning \
  --bucket "${TEMPLATE_BUCKET}" \
  --versioning-configuration Status=Enabled

CONNECTION_FILE="${PROJECT_ROOT}/.aws-connection.env"
{
  echo "ENVIRONMENT=${ENVIRONMENT}"
  echo "AWS_REGION=${AWS_REGION}"
  echo "AWS_DEFAULT_REGION=${AWS_REGION}"
  echo "AWS_STS_REGIONAL_ENDPOINTS=${AWS_STS_REGIONAL_ENDPOINTS}"
  echo "AWS_BIN=${AWS_BIN}"
  if [ -n "${AWS_PROFILE}" ]; then
    echo "AWS_PROFILE=${AWS_PROFILE}"
  fi
  echo "AWS_ACCOUNT_ID=${ACCOUNT_ID}"
  echo "TEMPLATE_BUCKET=${TEMPLATE_BUCKET}"
} > "${CONNECTION_FILE}"

echo
echo "AWS connection is ready."
echo "Connection settings written to ${CONNECTION_FILE}."
echo
echo "Next deployment command:"
echo "  cd ${PROJECT_ROOT}"
echo "  set -a && source .aws-connection.env && set +a"
echo "  bash scripts/deploy.sh ${ENVIRONMENT} <github-owner> <github-repo> <github-branch>"
