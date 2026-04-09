#!/usr/bin/env bash
# ecr-cleanup.sh — Delete untagged ECR images older than N days
# Usage: ./ecr-cleanup.sh --repo my-service --days 7 [--dry-run]
# Requires: aws cli, jq

set -euo pipefail

REPO=""
DAYS=7
DRY_RUN=false
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

usage() {
  echo "Usage: $0 --repo <repository-name> [--days <N>] [--dry-run] [--region <region>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)    REPO="$2";    shift 2 ;;
    --days)    DAYS="$2";    shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --region)  REGION="$2";  shift 2 ;;
    *)         usage ;;
  esac
done

[[ -z "$REPO" ]] && usage

CUTOFF=$(date -u -d "-${DAYS} days" +%s 2>/dev/null || date -u -v-"${DAYS}"d +%s)

echo "Scanning ECR repo: $REPO (region: $REGION)"
echo "Deleting untagged images pushed before: $(date -u -d @${CUTOFF} 2>/dev/null || date -u -r ${CUTOFF})"
echo ""

IMAGES=$(aws ecr list-images \
  --repository-name "$REPO" \
  --region "$REGION" \
  --filter tagStatus=UNTAGGED \
  --query 'imageIds[*]' \
  --output json)

if [[ "$IMAGES" == "[]" ]]; then
  echo "No untagged images found in $REPO."
  exit 0
fi

TO_DELETE=()
while IFS= read -r digest; do
  PUSHED=$(aws ecr describe-images \
    --repository-name "$REPO" \
    --region "$REGION" \
    --image-ids "imageDigest=$digest" \
    --query 'imageDetails[0].imagePushedAt' \
    --output text)
  PUSHED_TS=$(date -u -d "$PUSHED" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%S" "$PUSHED" +%s 2>/dev/null || echo 0)

  if [[ "$PUSHED_TS" -lt "$CUTOFF" ]]; then
    TO_DELETE+=("$digest")
    echo "  STALE: $digest (pushed: $PUSHED)"
  fi
done < <(echo "$IMAGES" | jq -r '.[].imageDigest')

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "No images older than ${DAYS} days."
  exit 0
fi

echo ""
echo "Found ${#TO_DELETE[@]} image(s) to delete."

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Skipping deletion. Remove --dry-run to apply."
  exit 0
fi

# Build imageIds JSON for batch delete
IDS_JSON=$(printf '{"imageDigest":"%s"},' "${TO_DELETE[@]}" | sed 's/,$//')
aws ecr batch-delete-image \
  --repository-name "$REPO" \
  --region "$REGION" \
  --image-ids "[${IDS_JSON}]" \
  --output json | jq '.imageIds | length' | xargs -I{} echo "Deleted {} images."
