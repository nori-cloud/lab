module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name}-cluster"
  kubernetes_version = local.cluster.version

  endpoint_public_access = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  addons = {
    external-dns = {
      pod_identity_association = [
        {
          role_arn        = aws_iam_role.external_dns.arn
          service_account = "external-dns"
        }
      ]
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  depends_on = [
    module.vpc
  ]
}

resource "aws_eks_access_entry" "iam_role" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.cluster.admin_role
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "iam_role_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.cluster.admin_role
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.iam_role]
}
