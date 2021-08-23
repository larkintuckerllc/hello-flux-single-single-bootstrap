output "install_path" {
  value = data.flux_install.this.path 
}

output "install_content" {
  value = data.flux_install.this.content
}

output "sync_path" {
  value = data.flux_sync.this.path 
}

output "sync_content" {
  value = data.flux_sync.this.content
}

output "kustomize_path" {
  value = data.flux_sync.this.kustomize_path 
}

output "kustomize_content" {
  value = data.flux_sync.this.kustomize_content
}

output "secret_name" {
  value = data.flux_sync.this.secret
}

output "secret_namespace" {
    value = data.flux_sync.this.namespace
}
