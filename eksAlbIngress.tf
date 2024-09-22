# AWS Load balancer controller (ingress) needs to be added to this module using helm charts.

# Create an IAM policy for ingress controller ( Remember ingress has three parts. Refer to notes) so that it can create and manage AWS ALB.
resource "aws_iam_policy" "aws_lb_ingress_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("awsLoadBalancerControllerIam.json")
}

# Who can assume this role - service account in kube-system namespace and name aws-load-balancer-controller
data "aws_iam_policy_document" "aws_lb_ingress_controller_assume_role_policy" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# IAM role Ingress controller to assume through service account.
resource "aws_iam_role" "aws_lb_ingress_controller_role" {
  name               = "AWSLoadBalancerControllerRole"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_ingress_controller_assume_role_policy.json
}


# Attach policy to the role
resource "aws_iam_role_policy_attachment" "aws_lb_ingress_controller_role_attachment" {
  role       = aws_iam_role.aws_lb_ingress_controller_role.name
  policy_arn = aws_iam_policy.aws_lb_ingress_controller.arn
}

# The above Role and policy can also be done using this terraform module

#module "aws_load_balancer_controller_irsa_role" {
#  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#  version = "5.3.1"
#
#  role_name = "aws-load-balancer-controller"
#
#  attach_load_balancer_controller_policy = true
#
#  oidc_providers = {
#    ex = {
#      provider_arn               = module.eks.oidc_provider_arn
#      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#    }
#  }
#}


resource "kubernetes_service_account" "aws_load_balancer_service_account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_ingress_controller_role.arn
    }
  }
}


# Create a helm release
resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  namespace       = "kube-system"
  version         = "2.8.0"
  cleanup_on_fail = true
  description     = "Helm release for AWS load balancer controller"

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = aws_vpc.eks_vpc.id
  }

  set {
    name  = "podDisruptionBudget.maxUnavailable"
    value = 1
  }

  set {
    name  = "clusterSecretsPermissions.allowAllSecrets"
    value = "true"
  }

  set {
    # Only ingress resources with this class name will be managed by this ingress-controller. alb is the default value as well.
    name  = "ingressClass"
    value = "alb"
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_lb_ingress_controller_role_attachment,
    kubernetes_service_account.aws_load_balancer_service_account
  ]
}
# TODO - Create an ingress resource in the services folder that has all the rules for this load balancer.