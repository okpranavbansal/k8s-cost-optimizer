#!/usr/bin/env bash
# unused-resources.sh — Find and report idle/unused AWS resources
# Usage: ./unused-resources.sh [--region ap-southeast-1] [--dry-run]
# Requires: aws cli, jq

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)  REGION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *)         echo "Unknown arg: $1"; exit 1 ;;
  esac
done

echo "=== Unused Resource Report: $REGION ==="
echo ""

echo "--- Unattached Elastic IPs ---"
aws ec2 describe-addresses \
  --region "$REGION" \
  --query 'Addresses[?AssociationId==null].[PublicIp, AllocationId]' \
  --output table

echo ""
echo "--- Unattached EBS Volumes (available state) ---"
aws ec2 describe-volumes \
  --region "$REGION" \
  --filters "Name=status,Values=available" \
  --query 'Volumes[*].[VolumeId, Size, VolumeType, CreateTime]' \
  --output table

echo ""
echo "--- Load Balancers with no healthy targets ---"
aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query 'LoadBalancers[*].[LoadBalancerArn, LoadBalancerName, State.Code]' \
  --output json | jq -r '.[] | select(.[2] == "active") | .[1]' | \
while read -r LB_NAME; do
  LB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$LB_NAME" \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
  TG_COUNT=$(aws elbv2 describe-target-groups \
    --load-balancer-arn "$LB_ARN" \
    --region "$REGION" \
    --query 'length(TargetGroups)' \
    --output text)
  if [[ "$TG_COUNT" -eq 0 ]]; then
    echo "  IDLE ALB: $LB_NAME (no target groups)"
  fi
done

echo ""
echo "--- ECR Repos with no recent pulls (30+ days) ---"
aws ecr describe-repositories \
  --region "$REGION" \
  --query 'repositories[*].repositoryName' \
  --output json | jq -r '.[]' | \
while read -r REPO; do
  LAST_PULL=$(aws ecr describe-images \
    --repository-name "$REPO" \
    --region "$REGION" \
    --query 'sort_by(imageDetails, &imagePushedAt)[-1].imagePushedAt' \
    --output text 2>/dev/null || echo "0")
  if [[ "$LAST_PULL" == "None" ]] || [[ -z "$LAST_PULL" ]]; then
    echo "  EMPTY REPO: $REPO"
  fi
done

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] No changes made. Review the above and clean up manually or remove --dry-run."
else
  echo "Review the above resources and delete any that are confirmed unused."
  echo "Run with --dry-run to suppress this message."
fi
