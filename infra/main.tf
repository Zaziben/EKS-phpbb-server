provider "aws" {
    region = var.aws_region
  }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.3.2"

  name    = var.cluster_name
  kubernetes_version = "1.33"
  endpoint_public_access = true


  enable_cluster_creator_admin_permissions = true
  enable_irsa = true
  include_oidc_root_ca_thumbprint = true

  vpc_id     = var.vpc_id  
  subnet_ids = ["subnet-048916d83b3d6dcf1", "subnet-07e4939eae8fcd6bb", "subnet-04181d7c9e2cc0f09", ]


  eks_managed_node_groups = {  
    group1 = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
   
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}

  }
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }

}

data "aws_s3_bucket" "s3" {
  bucket = "dnd-forum-s3-jv"
}

resource "aws_iam_role" "phpbb_irsa" {
  name = "eks-s3-phpbb-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:dnd-forum:dnd-sa"
          }
        }
      }
    ]
  })
}
data "aws_iam_policy_document" "phpbb_s3_access" {
  statement {
    sid    = "MountpointFullBucketAccess"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::dnd-forum-s3-jv"
    ]
  }

  statement {
    sid    = "MountpointFullObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:DeleteObject"
    ]
  }
}

resource "aws_iam_policy" "phpbb_s3_policy" {
  name   = "phpbb-s3-policy"
  policy = data.aws_iam_policy_document.phpbb_s3_access.json
}

resource "aws_iam_role_policy_attachment" "phpbb_s3_attach" {
  role       = aws_iam_role.phpbb_irsa.name
  policy_arn = aws_iam_policy.phpbb_s3_policy.arn
}

