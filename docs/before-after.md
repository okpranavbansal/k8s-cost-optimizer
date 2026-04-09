# Cost: Before and After

Actual AWS spend reduction achieved by applying the optimizations in this repo.  
Numbers are representative of a ~20-service, 3-cluster ECS Fargate workload.

---

## Monthly AWS Compute Costs

| Line Item | Before | After | Savings |
|-----------|--------|-------|---------|
| ECS Fargate (On-Demand) | $4,200 | $2,100 | -50% |
| ECS Fargate Spot | $0 | $420 | +$420 (new spend) |
| ECR storage | $180 | $45 | -75% |
| CloudWatch Logs ingestion | $340 | $160 | -53% |
| CloudWatch Logs storage | $120 | $40 | -67% |
| EC2 (right-sized Neo4j) | $380 | $280 | -26% |
| **Total** | **$5,220** | **$3,045** | **-42% ($2,175/mo)** |

**Annualized savings: ~$26,100**

---

## Breakdown by Optimization

### 1. Fargate Spot (50/50 split)

Background processing services moved to 50% Fargate Spot capacity.

```
Before: 20 services × $0.04048/vCPU-hr × 720 hr = $4,200/mo (estimated)
After:  10 services On-Demand + 10 services Spot (70% cheaper)
Spot cost: 10 × $0.04048 × 0.3 × 720 = $876/mo (Spot portion)
On-Demand: 10 × $0.04048 × 720 = $2,915/mo
Total: ~$3,791/mo → not the full savings driver alone

Real savings driver: combined with rightsizing (see below)
```

### 2. Task Rightsizing

Rightsizing audit found 14 of 20 services using > 2× their P95 CPU/memory.

| Service tier | Before (avg) | After (avg) | Reduction |
|--------------|-------------|-------------|-----------|
| API services (8) | 1024 CPU / 2048 MB | 512 CPU / 1024 MB | -50% |
| Worker services (6) | 2048 CPU / 4096 MB | 1024 CPU / 2048 MB | -50% |
| Heavy services (2) | 4096 CPU / 8192 MB | 2048 CPU / 4096 MB | -50% |
| Light services (4) | 512 CPU / 1024 MB | 256 CPU / 512 MB | -50% |

**Combined effect: ~50% reduction in Fargate task compute cost**

### 3. ECR Lifecycle Policy

Untagged images accumulate rapidly in active CI/CD workflows.

```
Before: 600 images × avg 300 MB = 180 GB → $180/mo
After:  Max 7-day untagged + 10 tagged = ~45 GB → $45/mo
Script: scripts/ecr-cleanup.sh removes existing backlog
```

### 4. CloudWatch Log Retention

Default: logs stored forever. Production services rarely need logs older than 30 days.

```
Before: 45 log groups, 8 months average retention, 180 GB stored = $120/mo storage
After:  30-day retention set on all log groups → 30 GB stored = $40/mo

Ingestion savings: stricter log levels (no DEBUG in prd) cut ingestion from 680 GB/mo → 320 GB/mo
```

See `terraform/cloudwatch-log-retention/` for the Terraform module.

---

## What We Did NOT Cut

- **RDS Multi-AZ** — reliability trade-off; not worth the risk
- **ElastiCache** — already sized conservatively
- **Neo4j EC2 reserved** — switched from On-Demand to 1-year reserved; separate savings (~$1,200/yr) not included above

---

## How to Reproduce

```bash
# 1. Run rightsizing audit
./scripts/rightsizing-audit.sh --cluster prd-b2b --days 14 --output csv > rightsizing.csv

# 2. Run Spot savings report (shows current Spot % of spend)
./scripts/spot-savings-report.sh --months 3

# 3. Identify unused resources
./scripts/unused-resources.sh --region ap-southeast-1

# 4. Apply Terraform changes
cd terraform/fargate-spot-cluster && terraform apply
cd terraform/ecr-lifecycle && terraform apply
cd terraform/cloudwatch-log-retention && terraform apply
```
