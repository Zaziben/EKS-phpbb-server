provider "aws" {
    region = var.aws_region
  }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  # Optional
  cluster_endpoint_public_access = true


  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  vpc_id     = var.vpc_id  
    subnet_ids = ["subnet-048916d83b3d6dcf1", "subnet-07e4939eae8fcd6bb", "subnet-04181d7c9e2cc0f09", ]


  eks_managed_node_groups = {  
    one = {
      name = "node-group-1"

      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
   
  cluster_addons = {
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver = {}
    vpc-cni = {}

  }
}

