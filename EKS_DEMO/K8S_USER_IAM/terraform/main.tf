terraform{
    required_providers {
      aws =  {
            source = "hashicorp/aws"
            version = "5.38.0"
        }
    }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_user" "demo-user" {
    name = "demo-user"
    path = "/"
}

resource "aws_iam_user_login_profile" "demo-user" {
  user = aws_iam_user.demo-user.name
  password_reset_required = true
}

resource "aws_iam_access_key" "demo-user" {
  user = aws_iam_user.demo-user.name
  pgp_key = file("C:/Users/Shree/Downloads/publicbase64.key")
}

output "secret_value" {
  value = aws_iam_access_key.demo-user.encrypted_secret
  description = "this is secret key for the user"
}

output "acces_id" {
  value = aws_iam_access_key.demo-user.id
}

output "user_onetime_pass" {
  value = aws_iam_user_login_profile.demo-user.password
  description = "this is pass for console login"
}


#user creation done, now we will assign permission to user so that it can acces to eks cluster by default person who creates cluster has full permissions
resource "aws_iam_policy" "EKS_describe" {
  name = "EKS_describe"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AccessAnalyzerServiceRolePolicy",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
})
}

resource "aws_iam_policy_attachment" "EKS_describe" {
  name = "EKS_describe"
  users = [aws_iam_user.demo-user.name]
  policy_arn = aws_iam_policy.EKS_describe.arn
}

#Now create eks acces entry to knoe which RBAC permission user should have

variable "eks_cluster_name" {
  default = "demo-eks-cluster"
  type = string
}

resource "aws_eks_access_entry" "dev" {
  cluster_name = var.eks_cluster_name
  principal_arn = aws_iam_user.demo-user.arn
  kubernetes_groups = ["dev"]
}