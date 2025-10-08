provider "aws" {
    region = var.aws_region
  }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.3.2"

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

data "aws_s3_bucket" "s3" {
  bucket = "dnd-forum-s3-jv"  # e.g., from output of your static stack
}

# IAM role for phpBB ServiceAccount

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
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:dnd-forum:phpbb"
          }
        }
      }
    ]
  })
}
# IAM policy granting access to the S3 bucket
data "aws_iam_policy_document" "phpbb_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]

    resources = [
      data.aws_s3_bucket.s3.arn,
      "${data.aws_s3_bucket.s3.arn}/*"
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

