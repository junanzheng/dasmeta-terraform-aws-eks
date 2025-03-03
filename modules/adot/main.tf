locals {
  service_account_name = "adot-collector"
  oidc_provider        = regex("^arn:aws:iam::[0-9]+:oidc-provider/(.*)$", var.oidc_provider_arn)[0]
  region               = coalesce(var.region, try(data.aws_region.current[0].name, null))


  logging = var.adot_config.logging_enable ? {
    "log_group_name"  = "${var.adot_config.log_group_name}"
    "log_stream_name" = "adot-metrics"
    "log_retention"   = "${var.adot_config.log_retention}"
  } : {}
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

resource "helm_release" "adot-collector" {
  name             = "adot-collector"
  repository       = "https://dasmeta.github.io/aws-otel-helm-charts"
  chart            = "adot-exporter-for-eks-on-ec2"
  namespace        = var.namespace
  version          = "0.15.5"
  create_namespace = false
  atomic           = true
  wait             = false

  values = [
    contains(keys(var.adot_config), "helm_values")
    && try(var.adot_config.helm_values, "") != null ?
    var.adot_config.helm_values :
    templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region                     = local.region
      cluster_name               = var.cluster_name
      accept_namespace_regex     = var.adot_config.accept_namespace_regex
      loging                     = local.logging
      metrics                    = local.merged_metrics
      metrics_namespace_specific = local.merged_namespace_specific
      prometheus_metrics         = var.prometheus_metrics
      namespace                  = var.namespace
      resources_limit_cpu        = var.adot_config.resources.limit["cpu"]
      resources_limit_memory     = var.adot_config.resources.limit["memory"]
      resources_requests_cpu     = var.adot_config.resources.requests["cpu"]
      resources_requests_memory  = var.adot_config.resources.requests["memory"]
    })
  ]

  depends_on = [
    aws_eks_addon.this,
    aws_iam_role.adot_collector
  ]
}
