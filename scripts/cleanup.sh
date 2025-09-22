#!/bin/bash

# GKE Multicluster Cleanup Script
# This script cleans up the GKE cluster and all resources

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

# Confirm cleanup
confirm_cleanup() {
    print_warning "This will delete the entire GKE cluster and all resources!"
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled."
        exit 0
    fi
}

# Clean up Kubernetes resources
cleanup_k8s_resources() {
    print_info "Cleaning up Kubernetes resources..."
    
    # Remove demo application
    print_info "Removing nginx demo application..."
    kubectl delete -f k8s/istio-gateway.yaml --ignore-not-found=true
    kubectl delete -f k8s/nginx-service.yaml --ignore-not-found=true
    kubectl delete -f k8s/nginx-deployment.yaml --ignore-not-found=true
    
    # Remove Istio
    print_info "Removing Istio components..."
    helm uninstall istio-ingressgateway -n istio-system --ignore-not-found
    helm uninstall istiod -n istio-system --ignore-not-found
    helm uninstall istio-base -n istio-system --ignore-not-found
    
    # Remove namespace labels
    kubectl label namespace default istio-injection- --ignore-not-found=true
    
    print_success "Kubernetes resources cleaned up."
}

# Destroy infrastructure with Terraform
destroy_infrastructure() {
    print_info "Destroying infrastructure with Terraform..."
    
    cd terraform
    
    print_info "Running terraform destroy..."
    terraform destroy -auto-approve
    
    cd ..
    
    print_success "Infrastructure destroyed successfully!"
}

# Main execution
main() {
    print_info "Starting cleanup process..."
    
    confirm_cleanup
    cleanup_k8s_resources
    destroy_infrastructure
    
    print_success "Cleanup completed! 🧹"
    print_info "All resources have been removed."
}

# Run main function
main "$@"