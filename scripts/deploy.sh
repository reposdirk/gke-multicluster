#!/bin/bash

# GKE Multicluster Setup Script
# This script sets up a GKE cluster with Istio and nginx demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

# Check if terraform.tfvars exists
check_terraform_vars() {
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_error "terraform.tfvars file not found!"
        print_info "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values:"
        print_info "cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
        print_info "Then edit terraform/terraform.tfvars with your GCP project ID and other settings."
        exit 1
    fi
}

# Deploy GKE cluster with Terraform
deploy_gke_cluster() {
    print_info "Deploying GKE cluster with Terraform..."
    
    cd terraform
    
    print_info "Initializing Terraform..."
    terraform init
    
    print_info "Planning Terraform deployment..."
    terraform plan
    
    print_info "Applying Terraform configuration..."
    terraform apply -auto-approve
    
    # Get kubectl credentials
    print_info "Configuring kubectl..."
    eval $(terraform output -raw kubectl_config_command)
    
    cd ..
    
    print_success "GKE cluster deployed successfully!"
}

# Install Istio using Helm
install_istio() {
    print_info "Installing Istio using Helm..."
    
    # Add Istio Helm repository
    print_info "Adding Istio Helm repository..."
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update
    
    # Create istio-system namespace
    print_info "Creating istio-system namespace..."
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Istio base
    print_info "Installing Istio base..."
    helm upgrade --install istio-base istio/base \
        -n istio-system \
        -f helm/istio-base-values.yaml \
        --wait
    
    # Install Istio control plane
    print_info "Installing Istio control plane (istiod)..."
    helm upgrade --install istiod istio/istiod \
        -n istio-system \
        -f helm/istiod-values.yaml \
        --wait
    
    # Install Istio ingress gateway
    print_info "Installing Istio ingress gateway..."
    helm upgrade --install istio-ingressgateway istio/gateway \
        -n istio-system \
        -f helm/istio-gateway-values.yaml \
        --wait
    
    # Label default namespace for Istio injection
    print_info "Enabling Istio sidecar injection for default namespace..."
    kubectl label namespace default istio-injection=enabled --overwrite
    
    print_success "Istio installed successfully!"
}

# Deploy nginx demo application
deploy_nginx_demo() {
    print_info "Deploying nginx demo application..."
    
    # Apply nginx deployment and service
    print_info "Deploying nginx application..."
    kubectl apply -f k8s/nginx-deployment.yaml
    kubectl apply -f k8s/nginx-service.yaml
    
    # Wait for deployment to be ready
    print_info "Waiting for nginx deployment to be ready..."
    kubectl rollout status deployment/nginx-demo --timeout=300s
    
    # Apply Istio gateway and virtual service
    print_info "Configuring Istio routing..."
    kubectl apply -f k8s/istio-gateway.yaml
    
    print_success "Nginx demo application deployed successfully!"
}

# Get service information
get_service_info() {
    print_info "Getting service information..."
    
    # Get ingress gateway external IP
    print_info "Waiting for ingress gateway to get external IP..."
    EXTERNAL_IP=""
    while [ -z $EXTERNAL_IP ]; do
        EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
        if [ -z $EXTERNAL_IP ]; then
            print_info "Waiting for external IP..."
            sleep 10
        fi
    done
    
    print_success "Setup completed successfully!"
    echo
    print_info "=== Service Information ==="
    echo -e "${GREEN}External IP:${NC} $EXTERNAL_IP"
    echo -e "${GREEN}Demo URL:${NC} http://$EXTERNAL_IP"
    echo
    print_info "=== Useful Commands ==="
    echo "kubectl get pods -n istio-system"
    echo "kubectl get pods"
    echo "kubectl get svc -n istio-system"
    echo "kubectl logs -n istio-system deployment/istiod"
}

# Main execution
main() {
    print_info "Starting GKE Multicluster setup..."
    
    check_prerequisites
    check_terraform_vars
    deploy_gke_cluster
    install_istio
    deploy_nginx_demo
    get_service_info
    
    print_success "All done! 🚀"
}

# Run main function
main "$@"