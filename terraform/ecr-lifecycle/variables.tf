variable "repository_name" {
  description = "ECR repository name (usually the service name)"
  type        = string
}

variable "environment" {
  description = "Deployment environment. UAT skips ECR creation (shares with STG)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
