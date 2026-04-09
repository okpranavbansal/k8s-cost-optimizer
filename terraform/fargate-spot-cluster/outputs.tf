output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.name
}
