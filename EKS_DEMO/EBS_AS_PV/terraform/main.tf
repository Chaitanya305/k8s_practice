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

data "tls_certificate" "tls" {
  url = data.aws_eks_cluster.cluster_testing.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc-provider" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls.certificates[0].sha1_fingerprint]
  url = data.aws_eks_cluster.cluster_testing.identity[0].oidc[0].issuer
}


locals {
  partition          = data.aws_partition.current_testing.id
  account_id         = data.aws_caller_identity.current_testing.account_id
  oidc_provider_arn  = replace(data.aws_eks_cluster.cluster_testing.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_name = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_provider_arn}"
}

resource "aws_iam_role" "ebs_csi_role" {
  name = "ebs_csi_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": {
        "Sid": "RoleForEbsCSI",
        "Effect": "Allow",
        "Principal": {"Federated": local.oidc_provider_name},
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {"StringEquals": {"${local.oidc_provider_arn}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"}}
    }
})
}

data "aws_iam_policy" "AmazonEBSCSIDriverPolicy" {
  name = "AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_policy_attachment" "ebs_csi" {
  name = "ebs_csi"
  roles = [aws_iam_role.ebs_csi_role.name]
  policy_arn = data.aws_iam_policy.AmazonEBSCSIDriverPolicy.arn
}

resource "aws_eks_addon" "ebs_csi_addon" {
  cluster_name = var.eks_cluster_name
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_role.arn
  depends_on = [ aws_iam_role.ebs_csi_role]
}
