module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  # Optional
  cluster_endpoint_public_access = true
    cluster_encryption_config = {
      resources       = ["secrets"]
      kms_key_arn = aws_kms_key.a
  }

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = var.vpc_id
  subnet_ids = ["subnet-07e4939eae8fcd6bb", "subnet-04181d7c9e2cc0f09", ]
  control_plane_subnet_ids = ["subnet-07c91559f4c8535ae", "subnet-09d75a39c650da09c" ]
  
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      desired_size   = 1
      max_size   = 2
      min_size   = 1
    }
  }
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
    
   
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
  }
}

resource "aws_kms_key" "a" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}
