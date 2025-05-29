variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
  default     = "dnd-cluster"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
  default = "vpc-0abae96f5ad67cf3d"
}

