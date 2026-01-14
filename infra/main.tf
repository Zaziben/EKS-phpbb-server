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

    resources = [
      "arn:aws:s3:::dnd-forum-s3-jv/*",
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

data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = [
        "system:serviceaccount:kube-system:alb-dnd-sa"
      ]
    }
  }
}

data "aws_iam_policy_document" "alb_controller" {
  statement {
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeListenerAttributes"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerPolicy"
  policy = data.aws_iam_policy_document.alb_controller.json
}

resource "aws_iam_role" "alb_controller" {
  name               = "aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

