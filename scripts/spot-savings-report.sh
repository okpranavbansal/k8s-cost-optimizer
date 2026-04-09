#!/usr/bin/env bash
# spot-savings-report.sh — Pull Fargate Spot vs On-Demand cost comparison from Cost Explorer
# Usage: ./spot-savings-report.sh [--months 3] [--region us-east-1]
# Requires: aws cli, jq, Cost Explorer access (ce:GetCostAndUsage)

set -euo pipefail

MONTHS=3
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
# Cost Explorer API is only available in us-east-1 regardless of cluster region
CE_REGION="us-east-1"

while [[ $# -gt 0 ]]; do
  case $1 in
    --months) MONTHS="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    *)        echo "Unknown arg: $1"; exit 1 ;;
  esac
done

START=$(date -u -d "-${MONTHS} months" +%Y-%m-01 2>/dev/null || date -u -v-"${MONTHS}"m +%Y-%m-01)
END=$(date -u +%Y-%m-01)

echo "Fargate Spot vs On-Demand Cost Report"
echo "Period: $START → $END"
echo ""

# On-Demand Fargate cost
# Note: --region is fixed to us-east-1; Cost Explorer API is global and only reachable there
OD_COST=$(aws ce get-cost-and-usage \
  --time-period Start="$START",End="$END" \
  --granularity MONTHLY \
  --filter '{
    "And": [
      {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Container Service"]}},
      {"Dimensions": {"Key": "USAGE_TYPE_GROUP", "Values": ["ECS: Fargate-vCPU-Hours:perCPU", "ECS: Fargate-GB-Hours:perGB"]}}
    ]
  }' \
  --metrics BlendedCost \
  --region "$CE_REGION" \
  --query 'ResultsByTime[*].Total.BlendedCost.Amount' \
  --output json 2>/dev/null | jq -r '[.[] | tonumber] | add // 0')

# Fargate Spot cost
SPOT_COST=$(aws ce get-cost-and-usage \
  --time-period Start="$START",End="$END" \
  --granularity MONTHLY \
  --filter '{
    "And": [
      {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Container Service"]}},
      {"Dimensions": {"Key": "USAGE_TYPE_GROUP", "Values": ["ECS: Fargate-Spot-vCPU-Hours:perCPU", "ECS: Fargate-Spot-GB-Hours:perGB"]}}
    ]
  }' \
  --metrics BlendedCost \
  --region "$CE_REGION" \
  --query 'ResultsByTime[*].Total.BlendedCost.Amount' \
  --output json 2>/dev/null | jq -r '[.[] | tonumber] | add // 0')

TOTAL=$(echo "$OD_COST + $SPOT_COST" | bc)
SAVINGS_PCT=$(echo "scale=1; $SPOT_COST / ($SPOT_COST + $OD_COST) * 100" | bc 2>/dev/null || echo "N/A")

echo "On-Demand Fargate cost: \$${OD_COST}"
echo "Fargate Spot cost:      \$${SPOT_COST}"
echo "Total ECS compute:      \$${TOTAL}"
echo ""
echo "Spot % of total spend:  ${SAVINGS_PCT}%"
echo ""
echo "Equivalent cost if 100% On-Demand (est): \$$(echo "scale=2; $TOTAL / 0.3 * 1" | bc 2>/dev/null || echo N/A)"
echo ""
echo "Note: Savings calculation assumes Spot is ~70% cheaper than On-Demand."
echo "For accurate comparison, run AWS Compute Optimizer or use Savings Plans analyzer."
