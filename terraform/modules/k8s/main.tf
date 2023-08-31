terraform {
  required_version = ">= 1.5.5"

  required_providers {
    kustomization = {
      source  = "kbst/kustomization"
      version = ">= 0.9.4"
    }
  }
}

locals {
  lb_controller_iam_role_name        = "aws-load-balancer-controller-role"
  lb_controller_service_account_name = "aws-load-balancer-controller"
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

provider "kustomization" {
  kubeconfig_raw = templatefile("${path.module}/templates/kubeconfig.tpl", {
    kubeconfig_name                 = var.cluster_name
    endpoint                        = var.cluster_endpoint
    cluster_auth_base64             = var.cluster_certificate_authority_data
    aws_authenticator_command       = "aws"
    aws_authenticator_command_args  = ["eks", "get-token", "--region", "${var.region}", "--cluster-name", "${var.cluster_name}", "--output", "json"]
    aws_authenticator_env_variables = []
  })
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks --profile ${var.profile} --region ${var.region} update-kubeconfig --name ${var.cluster_name}"
  }

  provisioner "local-exec" {
    command = "kubectl patch deployment coredns -n kube-system --type json -p='[{\"op\": \"remove\", \"path\": \"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type\"}]'"
  }

  provisioner "local-exec" {
    command = "kubectl rollout status deployment coredns -n kube-system"
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
  source = "github.com/rlgns98kr/terraform-aws-eks-external-secrets"

  enabled = true

  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = var.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.oidc_provider_arn
  helm_chart_version               = ""
  namespace                        = "default"
  create_namespace                 = false

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

data "kustomization_build" "argocd_applications" {
  path = "../ops/argocd/override_values/${var.network_name}/applications"
}

resource "kustomization_resource" "p0" {
  for_each = data.kustomization_build.argocd_applications.ids_prio[0]

  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.argocd_applications.manifests[each.value])
    : data.kustomization_build.argocd_applications.manifests[each.value]
  )

  depends_on = [null_resource.kubectl, helm_release.argocd]
}

# then loop through resources in ids_prio[1]
# and set an explicit depends_on on kustomization_resource.p0
# wait 2 minutes for any deployment or daemonset to become ready
resource "kustomization_resource" "p1" {
  for_each = data.kustomization_build.argocd_applications.ids_prio[1]

  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.argocd_applications.manifests[each.value])
    : data.kustomization_build.argocd_applications.manifests[each.value]
  )
  wait = true
  timeouts {
    create = "2m"
    update = "2m"
  }

  depends_on = [null_resource.kubectl, helm_release.argocd, kustomization_resource.p0]
}

# finally, loop through resources in ids_prio[2]
# and set an explicit depends_on on kustomization_resource.p1
resource "kustomization_resource" "p2" {
  for_each = data.kustomization_build.argocd_applications.ids_prio[2]

  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.argocd_applications.manifests[each.value])
    : data.kustomization_build.argocd_applications.manifests[each.value]
  )

  depends_on = [null_resource.kubectl, helm_release.argocd, kustomization_resource.p1]
}
