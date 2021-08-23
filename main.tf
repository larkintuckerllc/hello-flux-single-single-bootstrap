terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "= 0.2.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.11.3"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "= 2.4.1"
    }
  }
  required_version = "= 1.0.5"
}

# PROVIDER

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kubernetes_config_context
}

# DATA

data "flux_install" "this" {
  target_path = "clusters/${var.kubernetes_cluster_name}"
  version     = "v0.16.2"
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.this.content
}

data "flux_sync" "this" {
  branch      = var.github_repository_branch
  target_path = "clusters/${var.kubernetes_cluster_name}"
  url         = "https://github.com/${var.github_owner}/${var.github_repository_name}"
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.this.content
}

# LOCALS

locals {
  install = [ for v in data.kubectl_file_documents.install.documents : {
    data: yamldecode(v)
    content: v
  } ]
  known_hosts = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=="
  sync = [ for v in data.kubectl_file_documents.sync.documents : {
    data: yamldecode(v)
    content: v
  } ]
}

# FLUX INSTALL

resource "kubernetes_namespace" "this" {
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
  metadata {
    name = "flux-system"
  }
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.this]
  yaml_body = each.value
}

# FLUX SYNC

resource "kubernetes_secret" "this" {
  data = {
    identity       = var.github_repository_deploy_key_private
    "identity.pub" = var.github_repository_deploy_key_public
    known_hosts    = local.known_hosts
  }
  metadata {
    name      = data.flux_sync.this.secret
    namespace = data.flux_sync.this.namespace
  }
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubectl_manifest.install, kubernetes_secret.this]
  yaml_body = each.value
}
