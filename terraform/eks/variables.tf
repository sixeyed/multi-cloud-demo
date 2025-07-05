# Variables for EKS deployment

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = ""
}

variable "deploy_addons" {
  description = "Deploy Kubernetes addons (requires kubectl to be configured)"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "multi-cloud-demo-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.xlarge"
}

variable "min_node_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_ecr" {
  description = "Create ECR repository"
  type        = bool
  default     = true
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "multi-cloud-demo"
}

variable "enable_arm64_nodes" {
  description = "Enable ARM64 node group for Apple Silicon builds"
  type        = bool
  default     = true
}

variable "arm64_instance_type" {
  description = "EC2 instance type for ARM64 nodes"
  type        = string
  default     = "m6g.medium"  # ARM-based Graviton2
}

variable "arm64_desired_node_count" {
  description = "Desired number of ARM64 nodes"
  type        = number
  default     = 0
}

variable "arm64_min_node_count" {
  description = "Minimum number of ARM64 nodes"
  type        = number
  default     = 0
}

variable "arm64_max_node_count" {
  description = "Maximum number of ARM64 nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "MultiCloudDemo"
    ManagedBy   = "Terraform"
  }
}