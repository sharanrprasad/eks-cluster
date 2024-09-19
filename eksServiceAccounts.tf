
locals {
  cluster_fargate-service-account-name      = "over-reacted-cluster-fargate"
  cluster_fargate_service_account_namespace = "fargate-cluster"
}

# IAM assume policy for Fargate role
data "aws_iam_policy_document" "fargate_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.AWS_ACCOUNT}:oidc-provider/${module.eks.cluster_oidc_issuer_url}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.cluster_oidc_issuer_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # This policy can only be assumed by service account in this namespace and has this name. We can also change this to be StringLike and give service account name as * to be bit more generic.
    condition {
      test     = "StringEquals"
      variable = "${module.eks.cluster_oidc_issuer_url}:sub"
      values   = ["system:serviceaccount:${local.cluster_fargate_service_account_namespace}:${local.cluster_fargate-service-account-name}"]
    }
  }
}


# IAM role for EKS pods to assume.
resource "aws_iam_role" "fargate_s3_role" {
  name               = "fargate-s3-access-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role.json
}

# Attach S3 policy to the role
resource "aws_iam_role_policy_attachment" "fargate_s3_policy" {
  role       = aws_iam_role.fargate_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}



# Service account to be created with in EKS. This service account has a namespace and in the role we can say specify the
# service accounts within in a namespace that can assume the role as well.
resource "kubernetes_service_account" "fargate_s3_service_account" {
  metadata {
    name      = "over-reacted-cluster-fargate"
    namespace = "fargate-cluster"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fargate_s3_role.arn
    }
  }
}

# Specify the service account name in the deployment yaml file like this
# spec:
# serviceAccountName: my-service-account  # Link the service account here