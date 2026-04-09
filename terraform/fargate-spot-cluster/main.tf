module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  name = "${var.environment}-${var.cluster_name}"

  # Exec command logging — allows `aws ecs execute-command` for debugging
  configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.environment}-${var.cluster_name}"
      }
    }
  }

  # Keep exec logs for 1 day only — they can be very verbose and expensive
  cloudwatch_log_group_retention_in_days = 1

  # COST OPTIMIZATION: 50% of tasks run on Fargate Spot (~70% cheaper than On-Demand)
  # Spot tasks CAN be interrupted. Ensure your services handle SIGTERM gracefully.
  # Set FARGATE weight to 100 for stateful services (e.g. ClickHouse, Neo4j consumers)
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = var.fargate_weight
    }
    FARGATE_SPOT = {
      weight = var.fargate_spot_weight
    }
  }

  setting = [
    {
      name  = "containerInsights"
      value = var.container_insights
    }
  ]

  tags = var.tags
}
