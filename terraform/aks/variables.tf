# Variables for AKS deployment

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "multi-cloud-demo-aks-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "multi-cloud-demo-aks"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "mcdemo-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32.4"
}

variable "default_node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "default_node_vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "create_acr" {
  description = "Create Azure Container Registry"
  type        = bool
  default     = true
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "multiclouddemoacr"
}

variable "enable_arm64_nodes" {
  description = "Enable ARM64 node pool for Apple Silicon builds"
  type        = bool
  default     = true
}

variable "arm64_node_count" {
  description = "Initial number of ARM64 nodes"
  type        = number
  default     = 1
}

variable "arm64_min_node_count" {
  description = "Minimum number of ARM64 nodes for autoscaling"
  type        = number
  default     = 0
}

variable "arm64_max_node_count" {
  description = "Maximum number of ARM64 nodes for autoscaling"
  type        = number
  default     = 3
}

variable "arm64_node_vm_size" {
  description = "VM size for ARM64 node pool"
  type        = string
  default     = "Standard_D2ps_v5"  # ARM64-based VM
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