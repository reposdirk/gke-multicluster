# GKE Multicluster with Istio Demo

This repository demonstrates how to create a Google Kubernetes Engine (GKE) cluster using Terraform, deploy Istio service mesh using Helm, and set up an nginx service accessible through an Istio ingress gateway.

## 🏗️ Architecture

```
Internet → Istio Ingress Gateway → Istio Service Mesh → Nginx Service → Nginx Pods
```

## 📋 Prerequisites

Before you begin, ensure you have the following tools installed:

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3.0)
- A Google Cloud Platform account with billing enabled

## 🚀 Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd gke-multicluster
```

### 2. Set up GCP Authentication

```bash
# Login to GCP
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Configure Terraform Variables

```bash
# Copy the example variables file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit the file with your values
# At minimum, set your project_id
```

Example `terraform/terraform.tfvars`:
```hcl
project_id   = "my-gcp-project"
region       = "us-central1"
cluster_name = "gke-multicluster"
node_count   = 2
machine_type = "e2-medium"
preemptible  = true
env          = "demo"
```

### 4. Deploy Everything

Run the automated deployment script:

```bash
./scripts/deploy.sh
```

This script will:
1. ✅ Check prerequisites
2. 🏗️ Deploy GKE cluster with Terraform
3. 🕸️ Install Istio using Helm
4. 🚀 Deploy nginx demo application
5. 🌐 Configure Istio ingress gateway
6. 📊 Display service information

### 5. Access Your Application

After deployment, the script will display the external IP address. You can access your demo application at:

```
http://EXTERNAL_IP
```

### 6. Validate Your Deployment

Run the validation script to check the health of your deployment:

```bash
./scripts/validate.sh
```

This script will:
- ✅ Check cluster connectivity
- 🔍 Verify GKE cluster status
- 🕸️ Validate Istio installation
- 🚀 Check nginx demo application
- 🌐 Test HTTP connectivity

## 📁 Repository Structure

```
├── terraform/               # Terraform configurations
│   ├── main.tf              # Main Terraform configuration
│   ├── variables.tf         # Variable definitions
│   ├── outputs.tf           # Output definitions
│   └── terraform.tfvars.example  # Example variables file
├── helm/                    # Helm values files
│   ├── istio-base-values.yaml     # Istio base configuration
│   ├── istiod-values.yaml         # Istio control plane configuration
│   └── istio-gateway-values.yaml  # Istio ingress gateway configuration
├── k8s/                     # Kubernetes manifests
│   ├── nginx-deployment.yaml      # Nginx deployment and config
│   ├── nginx-service.yaml         # Nginx service
│   └── istio-gateway.yaml         # Istio Gateway and VirtualService
├── scripts/                 # Automation scripts
│   ├── deploy.sh            # Main deployment script
│   ├── validate.sh          # Deployment validation script
│   └── cleanup.sh           # Cleanup script
└── README.md               # This file
```

## 🔧 Manual Deployment Steps

If you prefer to deploy manually:

### 1. Deploy GKE Cluster

```bash
cd terraform
terraform init
terraform plan
terraform apply

# Configure kubectl
gcloud container clusters get-credentials gke-multicluster --region us-central1 --project YOUR_PROJECT_ID
```

### 2. Install Istio

```bash
# Add Istio Helm repository
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Create namespace
kubectl create namespace istio-system

# Install Istio components
helm install istio-base istio/base -n istio-system -f helm/istio-base-values.yaml
helm install istiod istio/istiod -n istio-system -f helm/istiod-values.yaml
helm install istio-ingressgateway istio/gateway -n istio-system -f helm/istio-gateway-values.yaml

# Enable Istio injection
kubectl label namespace default istio-injection=enabled
```

### 3. Deploy Nginx Demo

```bash
# Deploy application
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
kubectl apply -f k8s/istio-gateway.yaml

# Get external IP
kubectl get svc istio-ingressgateway -n istio-system
```

## 🛠️ Useful Commands

### Check Cluster Status
```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
```

### Check Istio Status
```bash
kubectl get pods -n istio-system
kubectl logs -n istio-system deployment/istiod
```

### Check Demo Application
```bash
kubectl get pods
kubectl logs deployment/nginx-demo
```

### Port Forward for Local Testing
```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
# Access at http://localhost:8080
```

## 🧹 Cleanup

To remove all resources:

```bash
./scripts/cleanup.sh
```

Or manually:

```bash
# Remove Kubernetes resources
kubectl delete -f k8s/
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

# Destroy infrastructure
cd terraform
terraform destroy
```

## 🔍 Troubleshooting

### Common Issues

1. **External IP Pending**: LoadBalancer services may take a few minutes to get an external IP
2. **Pod CrashLoopBackOff**: Check logs with `kubectl logs <pod-name>`
3. **Istio Sidecar Issues**: Ensure namespace has `istio-injection=enabled` label

### Debugging Commands

```bash
# Check cluster info
kubectl cluster-info

# Check node status
kubectl describe nodes

# Check Istio configuration
kubectl get gateway,virtualservice,destinationrule -A

# Check Istio proxy status
kubectl exec deployment/nginx-demo -c istio-proxy -- pilot-agent request GET stats/config_dump
```

## 📖 Learn More

- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.