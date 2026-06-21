module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.13"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  # Grant the Terraform caller cluster-admin so the kubernetes/helm
  # providers can bootstrap Cilium.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # NOTE: the vpc-cni add-on is intentionally NOT installed.
  # CoreDNS is deferred until Cilium provides networking (see cilium.tf).
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [{
          key      = "node.cilium.io/agent-not-ready"
          operator = "Exists"
          effect   = "NoExecute"
        }]
      })
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # Cilium taints fresh nodes until the agent is ready; this is the
      # recommended pattern when Cilium owns the CNI.
      labels = {
        "io.cilium/managed" = "true"
      }
    }
  }

  tags = var.tags
}
