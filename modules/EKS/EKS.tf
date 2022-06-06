##################################################################################
# EKS Cluster Configuration
##################################################################################

resource "aws_eks_cluster" "eks" {
  name     = "${var.project_naming}-cluster"
  version  = var.k8s_version
  role_arn = aws_iam_role.eksRole.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    # public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    # aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.eks.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates.0.sha1_fingerprint]
  url = aws_eks_cluster.eks.identity.0.oidc.0.issuer
}


##################################################################################
# Node Group for EKS
##################################################################################

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.project_naming}-application-nodeGroup"
  node_role_arn   = aws_iam_role.ngRole.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  ami_type      = var.node_group_ami_type
  capacity_type = var.node_group_capacity_type
  disk_size     = var.node_group_disk_size
  # force_update_version = false

  instance_types = var.node_group_instance_types

  labels = var.node_group_labels

  update_config {
    max_unavailable = 1
  }
  
  lifecycle {
  ignore_changes = [scaling_config.0.desired_size]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(
    local.node_tag,
    local.autoscaler_tag,
  )
}
