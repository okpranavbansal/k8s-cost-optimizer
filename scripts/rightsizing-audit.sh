#!/usr/bin/env bash
# rightsizing-audit.sh — Identify over-provisioned ECS Fargate tasks
# Compares task CPU/memory reservations vs actual P95 utilization from CloudWatch
# Usage: ./rightsizing-audit.sh --cluster prd-platform [--days 14] [--output csv]
# Requires: aws cli, jq, bc

set -euo pipefail

CLUSTER=""
DAYS=14
OUTPUT="table"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
CPU_THRESHOLD=40   # flag if P95 CPU < 40% of reserved
MEM_THRESHOLD=50   # flag if P95 Memory < 50% of reserved

usage() {
  echo "Usage: $0 --cluster <cluster-name> [--days <N>] [--output table|csv] [--region <region>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --days)    DAYS="$2";    shift 2 ;;
    --output)  OUTPUT="$2";  shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    *)         usage ;;
  esac
done

[[ -z "$CLUSTER" ]] && usage

END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_TIME=$(date -u -d "-${DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
             date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)

echo "Auditing cluster: $CLUSTER (last ${DAYS} days)"
echo ""

if [[ "$OUTPUT" == "csv" ]]; then
  echo "service,reserved_cpu,reserved_mem_mb,p95_cpu_pct,p95_mem_pct,cpu_waste_pct,mem_waste_pct,recommendation"
fi

SERVICES=$(aws ecs list-services \
  --cluster "$CLUSTER" \
  --region "$REGION" \
  --query 'serviceArns[*]' \
  --output json | jq -r '.[]')

while IFS= read -r SERVICE_ARN; do
  SERVICE_NAME=$(basename "$SERVICE_ARN")

  # Get task definition to extract CPU/memory reservations
  TASK_DEF=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].taskDefinition' \
    --output text)

  RESERVED=$(aws ecs describe-task-definition \
    --task-definition "$TASK_DEF" \
    --region "$REGION" \
    --query '{cpu: taskDefinition.cpu, memory: taskDefinition.memory}' \
    --output json)

  RESERVED_CPU=$(echo "$RESERVED" | jq -r '.cpu // "256"')
  RESERVED_MEM=$(echo "$RESERVED" | jq -r '.memory // "512"')

  # Query CloudWatch Container Insights for P95 utilization.
  # CloudWatch get-metric-statistics max period is 86400s (1 day).
  # We use 1-day periods across the window and take the max daily P95
  # as a conservative estimate of peak utilization.
  P95_CPU=$(aws cloudwatch get-metric-statistics \
    --namespace "ECS/ContainerInsights" \
    --metric-name "CpuUtilized" \
    --dimensions Name=ClusterName,Value="$CLUSTER" Name=ServiceName,Value="$SERVICE_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 86400 \
    --statistics Maximum \
    --region "$REGION" \
    --query 'sort_by(Datapoints, &Timestamp)[-1].Maximum // `0`' \
    --output text 2>/dev/null || echo "0")

  P95_MEM=$(aws cloudwatch get-metric-statistics \
    --namespace "ECS/ContainerInsights" \
    --metric-name "MemoryUtilized" \
    --dimensions Name=ClusterName,Value="$CLUSTER" Name=ServiceName,Value="$SERVICE_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 86400 \
    --statistics Maximum \
    --region "$REGION" \
    --query 'sort_by(Datapoints, &Timestamp)[-1].Maximum // `0`' \
    --output text 2>/dev/null || echo "0")

  CPU_PCT=$(echo "scale=1; $P95_CPU / $RESERVED_CPU * 100" | bc 2>/dev/null || echo "N/A")
  MEM_PCT=$(echo "scale=1; $P95_MEM / $RESERVED_MEM * 100" | bc 2>/dev/null || echo "N/A")

  REC=""
  if (( $(echo "$CPU_PCT < $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    NEW_CPU=$(echo "scale=0; $RESERVED_CPU * 0.5 / 1" | bc)
    REC+="Reduce CPU to ${NEW_CPU}; "
  fi
  if (( $(echo "$MEM_PCT < $MEM_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    NEW_MEM=$(echo "scale=0; $RESERVED_MEM * 0.6 / 1" | bc)
    REC+="Reduce memory to ${NEW_MEM}MB; "
  fi
  [[ -z "$REC" ]] && REC="OK"

  if [[ "$OUTPUT" == "csv" ]]; then
    echo "${SERVICE_NAME},${RESERVED_CPU},${RESERVED_MEM},${CPU_PCT},${MEM_PCT},$(echo "100 - $CPU_PCT" | bc 2>/dev/null || echo N/A),$(echo "100 - $MEM_PCT" | bc 2>/dev/null || echo N/A),\"${REC}\""
  else
    printf "%-40s  CPU: %5s/%4s vCPU (%5s%%)  MEM: %5s/%5s MB (%5s%%)  %s\n" \
      "$SERVICE_NAME" "$P95_CPU" "$RESERVED_CPU" "$CPU_PCT" \
      "$P95_MEM" "$RESERVED_MEM" "$MEM_PCT" "$REC"
  fi
done <<< "$SERVICES"
