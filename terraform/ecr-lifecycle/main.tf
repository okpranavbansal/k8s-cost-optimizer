# COST OPTIMIZATION: ECR image lifecycle
# Deletes untagged images after 7 days — these are dangling layers from CI builds
# In a 37-service platform this can accumulate 10-15 GB/repo/month without cleanup

module "ecr" {
  # Skip ECR creation for UAT — UAT shares images with STG to avoid duplication
  count = var.environment == "uat" ? 0 : 1

  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name = var.repository_name

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the 10 most recent tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  repository_image_tag_mutability = "MUTABLE"

  manage_registry_scanning_configuration = true
  registry_scan_type                     = "BASIC"

  tags = var.tags
}
