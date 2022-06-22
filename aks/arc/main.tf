terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.10.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "arc" {
  name     = "${var.prefix}-arc"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "arc" {
  name                = "${var.prefix}-arc"
  location            = azurerm_resource_group.arc.location
  resource_group_name = azurerm_resource_group.arc.name
  dns_prefix          = "${var.prefix}-arc"

  default_node_pool {
    name       = "ngsystem"
    node_count = 1
    vm_size    = "Standard_D8s_v3"
    zones      = ["1", "2", "3"]
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  identity {
    type = "SystemAssigned"
  }

  private_cluster_enabled = false
}

resource "azurerm_kubernetes_cluster_node_pool" "arc-nodepool-linux-user" {
  name                  = "nglinux"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.arc.id
  os_type               = "Linux"
  vm_size               = "Standard_D8s_v3"
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 5
  node_count            = 1
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = "-1"
  os_disk_size_gb       = 256
  zones                 = ["1", "2", "3"]
  node_labels           = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = [
    "linux=true:NoSchedule",
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "arc-nodepool-windows-user" {
  name                  = "ngwin"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.arc.id
  os_type               = "Windows"
  vm_size               = "Standard_D8s_v3"
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 5
  node_count            = 1
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = "-1"
  os_disk_size_gb       = 256
  zones                 = ["1", "2", "3"]
  node_labels           = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = [
    "windows=true:NoSchedule",
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}

resource "null_resource" "cert-manager-deployment" {
  depends_on = [
    azurerm_kubernetes_cluster.arc,
    azurerm_kubernetes_cluster_node_pool.arc-nodepool-linux-user,
    azurerm_kubernetes_cluster_node_pool.arc-nodepool-windows-user,
  ]

  provisioner "local-exec" {
    when = create
    command = <<-EOF
      set -euo pipefail

      kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.1/cert-manager.yaml
      kubectl create -f https://github.com/actions-runner-controller/actions-runner-controller/releases/download/v0.24.1/actions-runner-controller.yaml
      kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_app_id=${var.app_id} --from-literal=github_app_installation_id=${var.installation_id} --from-file=github_app_private_key=${var.private_key_file_path}
      kubectl set env deploy controller-manager -c manager GITHUB_ENTERPRISE_URL=${var.github_url} --namespace actions-runner-system
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -euo pipefail

      kubectl delete namespace actions-runner-system
      kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.1/cert-manager.yaml
    EOF
  }
}
