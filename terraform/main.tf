# --- SECTION 1: Meta-Configuration ---
# The 'terraform' block defines which external 'plugins' (providers) 
# Terraform needs to download to talk to your tools.
terraform {
  required_providers {
    # The k3d provider allows Terraform to create and manage your 
    # local Kubernetes cluster instead of running 'k3d cluster create' manually.
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "0.0.7"
    }
    # The kubernetes provider allows Terraform to create namespaces, 
    # deployments, and services inside the cluster.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    # The helm provider manages 'Helm Charts' (Kubernetes packages).
    # We use this to install complex apps like ArgoCD.
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

# --- SECTION 2: The Infrastructure (The Cluster) ---
# This resource creates your 'mlops' cluster. 
# It mirrors your manual command: k3d cluster create mlops --agents 1 -p "8080:80@loadbalancer".
resource "k3d_cluster" "mlops" {
  name    = "mlops"
  servers = 1
  agents  = 1

  # This maps port 8080 on your WSL/Windows host to port 80 in the cluster.
  port {
    host_port      = 8080
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  # Automatically updates your ~/.kube/config so 'kubectl' works immediately.
  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context    = true
  }
}

# --- SECTION 3: Provider Configuration ---
# These blocks tell the plugins HOW to connect to your specific cluster.
# They use the credentials from the k3d cluster created above so 
# Terraform can log in and install apps.
provider "kubernetes" {
  # We reference the cluster resource we defined above to get the login info.
  host                   = k3d_cluster.mlops.credentials[0].host
  client_certificate     = k3d_cluster.mlops.credentials[0].client_certificate
  client_key             = k3d_cluster.mlops.credentials[0].client_key
  cluster_ca_certificate = k3d_cluster.mlops.credentials[0].cluster_ca_certificate
}

provider "helm" {
  # Some versions allow/require these at the root of the provider block
  # rather than inside a kubernetes { } sub-block.
  config_path    = "~/.kube/config"
  config_context = "k3d-mlops"
}

# --- SECTION 4: Resources (Namespaces & Apps) ---
# Replaces 'kubectl create namespace argocd'.
# This creates a logical 'folder' inside your cluster for ArgoCD.
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Replaces your manual 'kubectl apply' for ArgoCD installation.
# Helm is the preferred way to install ArgoCD as it handles all the yaml files for you.
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.4"

  # This replaces your 'argocd-cm-insecure.yaml' logic.
  # It tells ArgoCD to run over HTTP (insecure) for local testing.
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# Prepares the namespace for your local Git server (Gitea).
resource "kubernetes_namespace" "gitea" {
  metadata {
    name = "gitea"
  }
}