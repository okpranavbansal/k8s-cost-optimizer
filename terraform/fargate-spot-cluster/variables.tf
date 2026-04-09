variable "environment" {
  description = "Deployment environment (prd, stg, uat)"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name suffix (e.g. platform, b2b, discovery)"
  type        = string
}

variable "fargate_weight" {
  description = "Weight for On-Demand Fargate capacity provider (0-100)"
  type        = number
  default     = 50
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider (0-100). Higher = more Spot tasks = more savings but more interruption risk."
  type        = number
  default     = 50
}

variable "container_insights" {
  description = "Enable CloudWatch Container Insights. Set 'enabled' for prd, 'disabled' for stg/uat to save cost."
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be 'enabled' or 'disabled'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
