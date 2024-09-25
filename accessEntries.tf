# There are two ways to configure access entries.

# 1. Using access policies which are a fixed set of permissions from AWS


# Usually this will be a role for Federated login (users assume role there) and must be defined in the variables.
locals {
  access_entry_principles = ["arn:aws:iam::024848477348:user/sharanrpadmin"]
}


resource "aws_eks_access_entry" "admin_access_entry" {
  for_each          = toset(local.access_entry_principles)
  cluster_name      = module.eks.cluster_name
  principal_arn     = each.key
  kubernetes_groups = ["devs-group"] # - Groups can be specified when there is a role or cluster role binding. See ClusterRole binding below.
  type              = "STANDARD"
  depends_on        = [kubernetes_cluster_role_binding.devs_binding]
}


resource "aws_eks_access_policy_association" "example" {
  for_each      = toset(local.access_entry_principles)
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy" # Policy provided by AWS.
  principal_arn = each.key # This is the user or role arn

  access_scope {
    type = "cluster" //access across the cluster
  }
}


# 2. Using Cluster Role and Cluster Role bindings (RBAC). This gives more control in letting us pick what permissions exactly can be given.

# Create a K8s role
resource "kubernetes_cluster_role" "get_resources_role" {
  metadata {
    name = "get-resources-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch"]
  }
}

# Bind the role to a K8s group.
resource "kubernetes_cluster_role_binding" "devs_binding" {
  metadata {
    name = "get-resources-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.get_resources_role.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "devs-group"  # Kubernetes group that needs to be put in an access group.
    api_group = "rbac.authorization.k8s.io"
  }
}