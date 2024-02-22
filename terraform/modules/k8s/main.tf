terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

locals {
  lb_controller_iam_role_name        = "aws-load-balancer-controller-role-${var.cluster_name}"
  lb_controller_service_account_name = "aws-load-balancer-controller"
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    command     = "aws"
  }
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks --profile ${var.profile} --region ${var.region} update-kubeconfig --name ${var.cluster_name} --kubeconfig ~/.kube/config_temp"
  }

  provisioner "local-exec" {
    command    = "kubectl --kubeconfig ~/.kube/config_temp patch deployment coredns -n kube-system --type json -p='[{\"op\": \"remove\", \"path\": \"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type\"}]'"
    on_failure = continue
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ~/.kube/config_temp rollout restart deployment coredns -n kube-system"
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ~/.kube/config_temp rollout status deployment coredns -n kube-system"
  }

  provisioner "local-exec" {
    command = "rm -rf ~/.kube/config_temp"
  }

  depends_on = [var.fargate_profiles]
}

module "lb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name        = local.lb_controller_iam_role_name
  role_path        = "/"
  role_description = "Used by AWS Load Balancer Controller for EKS"

  role_permissions_boundary_arn = ""

  provider_url = replace(var.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:${local.lb_controller_service_account_name}"
  ]
  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]
}

data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "controller" {
  name_prefix = "AWSLoadBalancerControllerIAMPolicy"
  policy      = data.http.iam_policy.response_body
  role        = module.lb_controller_role.iam_role_name
}

resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"

  dynamic "set" {
    for_each = {
      "clusterName"           = var.cluster_name
      "serviceAccount.create" = "true"
      "serviceAccount.name"   = local.lb_controller_service_account_name
      "region"                = var.region
      "vpcId"                 = var.vpc.vpc_id

      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.lb_controller_role.iam_role_arn
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [null_resource.kubectl, module.lb_controller_role, aws_iam_role_policy.controller]
}

module "external_dns" {
  source  = "DNXLabs/eks-external-dns/aws"
  version = "0.2.0"

  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = var.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.oidc_provider_arn
  helm_repo_url                    = "https://kubernetes-sigs.github.io/external-dns"
  helm_chart_version               = ""

  depends_on = [null_resource.kubectl, helm_release.aws-load-balancer-controller, var.aws_acm_certificate_validation]
}

resource "kubernetes_storage_class" "efs-sc" {
  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
}

module "eks-external-secrets" {
  source  = "DNXLabs/eks-external-secrets/aws"
  version = "2.2.0"

  enabled = true

  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = var.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.oidc_provider_arn
  helm_chart_version               = ""
  namespace                        = var.external_secret_namespace
  create_namespace                 = true

  settings = {
    "webhook" : {
      "port" : 9443
    }
  }

  depends_on = [var.aws_secretsmanager_id, null_resource.kubectl, helm_release.aws-load-balancer-controller]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = "argocd"
  create_namespace = true

  values = [
    file("../ops/argocd/override_values/${var.network_name}/values.yaml")
  ]

  depends_on = [null_resource.kubectl, helm_release.aws-load-balancer-controller, module.external_dns]
}

resource "kubectl_manifest" "argocd_applications" {
  yaml_body = file("../ops/argocd/override_values/${var.network_name}/applications.yaml")

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "resources" {
  for_each = fileset(path.module, "resources/**")

  yaml_body = file("${path.module}/${each.value}")

  depends_on = [null_resource.kubectl]
}
