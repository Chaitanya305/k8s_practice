terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "5.38.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "eks_cluster_name" {
  default = "demo-eks-cluster"
  type = string
}

data "aws_partition" "current_testing" {}

data "aws_caller_identity" "current_testing" {}

data "aws_eks_cluster" "cluster_testing" {
  name = var.eks_cluster_name
}

locals {
  partition          = data.aws_partition.current_testing.id
  account_id         = data.aws_caller_identity.current_testing.account_id
  oidc_provider_arn  = replace(data.aws_eks_cluster.cluster_testing.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_name = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_provider_arn}"
}

resource "aws_iam_role" "web_s3_access_role" {
  name = "web_s3_access_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": {
        "Sid": "RoleFors3access",
        "Effect": "Allow",
        "Principal": {"Federated": local.oidc_provider_name},
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {"StringEquals": {"${local.oidc_provider_arn}:sub": "system:serviceaccount:default:demo-sa"}}
    }
})
}

resource "aws_iam_policy" "s3_access" {
  name = "s3_access"
  policy = jsonencode({
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"s3:PutObject",
				"s3:GetObject",
				"s3:ListBucket",
				"s3:DeleteObject",
                "s3:ListAllMyBuckets"
			],
			"Resource": "*"
		}
	]
})
}

resource "aws_iam_policy_attachment" "s3_access" {
  policy_arn = aws_iam_policy.s3_access.arn
  roles = [aws_iam_role.web_s3_access_role.name]
  name = "s3_access"
}

output "role_arn" {
  value = aws_iam_role.web_s3_access_role.arn
  description = "this need to be use in sa annotations"
}