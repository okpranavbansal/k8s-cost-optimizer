# k8s-cost-optimizer
> Scripts and automation that achieved 50–60% AWS infrastructure cost reduction for a production ECS Fargate platform.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white) ![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white) ![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white) ![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white) ![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)

Terraform modules and shell scripts that achieved **50–60% AWS infrastructure cost reduction** for a production ECS Fargate platform running 37 microservices.

> These are real patterns extracted from production. Numbers are sanitized approximations.

---

## Results

| Optimization | Monthly Saving | Effort |
|-------------|----------------|--------|
| Fargate Spot (50/50 strategy) | ~$3,800 | Low — 1 Terraform change |
| ECR image lifecycle (7-day untagged cleanup) | ~$120 | Low — per-service module |
| CloudWatch log retention (1 day debug, 7 day access) | ~$180 | Low — module default |
| Right-sizing over-provisioned tasks | ~$900 | Medium — 2 weeks of metrics review |
| Unused EIP + idle ALB cleanup | ~$80 | Low — run cleanup script once |
| **Total** | **~$5,080/mo** | |

---

## Repository Structure

```
k8s-cost-optimizer/
├── README.md
├── terraform/
│   ├── fargate-spot-cluster/     # ECS cluster with 50/50 Spot strategy
│   ├── ecr-lifecycle/            # ECR image expiry automation
│   └── cloudwatch-log-retention/ # Log group retention policy
├── scripts/
│   ├── ecr-cleanup.sh            # Delete untagged ECR images older than N days
│   ├── spot-savings-report.sh    # Pull Spot vs On-Demand savings from Cost Explorer
│   ├── rightsizing-audit.sh      # Flag over-provisioned ECS tasks
│   └── unused-resources.sh       # Find idle ALBs, EIPs, unattached EBS
└── docs/
    ├── cost-strategy.md          # Full playbook
    └── before-after.md           # Cost breakdown tables
```

---

## Quick Start

### 1. Enable Fargate Spot on your ECS cluster

```bash
cd terraform/fargate-spot-cluster
terraform init
terraform apply -var="environment=prd" -var="cluster_name=platform"
```

### 2. Add ECR lifecycle to each service

```bash
cd terraform/ecr-lifecycle
terraform apply -var="repository_name=my-service" -var="environment=prd"
```

### 3. Run the right-sizing audit

```bash
# Requires: aws CLI, jq
# Output: CSV of over-provisioned services
./scripts/rightsizing-audit.sh --cluster prd-platform --days 14
```

---

## Prerequisites

- AWS CLI configured with Cost Explorer access (`ce:*`)
- Terraform >= 1.5
- `jq`, `bc` for shell scripts

## Author

**Pranav Bansal** — AI Infrastructure & SRE Engineer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/okpranavbansal)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white)](https://github.com/okpranavbansal)