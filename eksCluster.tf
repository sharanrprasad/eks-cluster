
locals {
  public_subnets  = aws_subnet.eks_vpc_public_subnets[*].id
  all_subnet_ids  = concat(aws_subnet.eks_vpc_public_subnets[*].id, aws_subnet.eks_vpc_private_subnets[*].id)
  private_subnets = aws_subnet.eks_vpc_private_subnets[*].id
  cluster_name    = "over-reacted-cluster"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.24.1"
  cluster_name    = local.cluster_name
  cluster_version = "1.30"
  # It's not just these AWS provided add ons we can also add EKS market place addons.
  # use this command to get all available addons (Different command to get options) - aws eks describe-addon-versions --query 'addons[*].addonName'
  # Add ons follow the same syntax as defined in AWS terraform provider - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
  cluster_addons = {
    coredns = {}
    #    coredns = {
    #      most_recent = true
    #      configuration_values = jsonencode({
    #        computeType = "Fargate"
    #      })
    #    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
  subnet_ids = local.private_subnets
  # Control plane is in AWS managed VPC and this will place an ENI inside our VPC so that control plane can talk to it.
  control_plane_subnet_ids = local.private_subnets
  vpc_id                   = aws_vpc.eks_vpc.id

  enable_cluster_creator_admin_permissions = true
  # kubectl command can be accessed outside the VPC as well.
  cluster_endpoint_public_access = true

  # IAM Role for the cluster
  create_iam_role      = true
  iam_role_name        = "over-reacted-cluster-role"
  iam_role_description = "Role used by the cluster"
  iam_role_tags = {
    resource = "over-reacted-cluster"
  }

  # OIDC provider enabled for `IAM roles for service accounts` so that pods have access to AWS resources. See eksServiceAccounts.tf for example.
  enable_irsa = true

  # Cluster security group to be placed on ENI
  # Fargate profiles use the cluster primary security group so these are not utilized. cluster_security_group ensures communication between cluster and nodes.
  create_cluster_security_group = false
  create_node_security_group    = false


  # Fargate profiles - Here we define what pods with namespace needs to run as Fargate. Options here come from Fargate module inside EKS module. Refer github.
  fargate_profiles = {
    # This makes sure that things like CoreDNS which runs as pods in K8s uses fargate. kube-system is the default namespace.
    kube_system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
      # Fargate pod execution IAM role for fargate to communicate with Control plane to register as Nodes. Value is true by default.
      create_iam_role = true
      iam_role_name   = "kube-system-pod-execution-role"
    }
    # Here we say all the pods which have namespace like fargate-* will run on Fargate. We can also make some pods run as Managed node groups.
    app_wildcard = {
      name = "app-wildcard"
      selectors = [
        { namespace = "fargate-*" }
      ]
    }
  }

}

