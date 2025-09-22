#!/bin/bash

# GKE Multicluster Validation Script
# This script validates the deployment and tests connectivity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if cluster is accessible
check_cluster_access() {
    print_info "Checking cluster access..."
    if kubectl cluster-info &> /dev/null; then
        print_success "Cluster is accessible"
    else
        print_error "Cannot access cluster. Make sure kubectl is configured correctly."
        exit 1
    fi
}

# Check GKE cluster status
check_gke_cluster() {
    print_info "Checking GKE cluster status..."
    
    NODES=$(kubectl get nodes --no-headers | wc -l)
    READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready ")
    
    echo "Total nodes: $NODES"
    echo "Ready nodes: $READY_NODES"
    
    if [ "$NODES" -eq "$READY_NODES" ]; then
        print_success "All nodes are ready"
    else
        print_warning "Some nodes are not ready"
    fi
}

# Check Istio installation
check_istio() {
    print_info "Checking Istio installation..."
    
    # Check istio-system namespace
    if kubectl get namespace istio-system &> /dev/null; then
        print_success "istio-system namespace exists"
    else
        print_error "istio-system namespace not found"
        return 1
    fi
    
    # Check Istio pods
    ISTIO_PODS=$(kubectl get pods -n istio-system --no-headers | wc -l)
    RUNNING_PODS=$(kubectl get pods -n istio-system --no-headers | grep -c "Running" || true)
    
    echo "Total Istio pods: $ISTIO_PODS"
    echo "Running Istio pods: $RUNNING_PODS"
    
    if [ "$ISTIO_PODS" -eq "$RUNNING_PODS" ] && [ "$ISTIO_PODS" -gt 0 ]; then
        print_success "All Istio pods are running"
    else
        print_warning "Some Istio pods are not running"
        kubectl get pods -n istio-system
    fi
    
    # Check ingress gateway service
    if kubectl get svc istio-ingressgateway -n istio-system &> /dev/null; then
        print_success "Istio ingress gateway service exists"
        
        EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            print_success "Ingress gateway has external IP: $EXTERNAL_IP"
        else
            print_warning "Ingress gateway external IP is pending"
        fi
    else
        print_error "Istio ingress gateway service not found"
    fi
}

# Check nginx demo application
check_nginx_demo() {
    print_info "Checking nginx demo application..."
    
    # Check deployment
    if kubectl get deployment nginx-demo &> /dev/null; then
        print_success "nginx-demo deployment exists"
        
        DESIRED=$(kubectl get deployment nginx-demo -o jsonpath='{.spec.replicas}')
        READY=$(kubectl get deployment nginx-demo -o jsonpath='{.status.readyReplicas}')
        
        echo "Desired replicas: $DESIRED"
        echo "Ready replicas: $READY"
        
        if [ "$DESIRED" -eq "$READY" ]; then
            print_success "All nginx replicas are ready"
        else
            print_warning "Some nginx replicas are not ready"
        fi
    else
        print_error "nginx-demo deployment not found"
    fi
    
    # Check service
    if kubectl get service nginx-demo-service &> /dev/null; then
        print_success "nginx-demo-service exists"
    else
        print_error "nginx-demo-service not found"
    fi
    
    # Check Istio resources
    if kubectl get gateway nginx-demo-gateway &> /dev/null; then
        print_success "nginx-demo-gateway exists"
    else
        print_error "nginx-demo-gateway not found"
    fi
    
    if kubectl get virtualservice nginx-demo-vs &> /dev/null; then
        print_success "nginx-demo-vs exists"
    else
        print_error "nginx-demo-vs not found"
    fi
}

# Test HTTP connectivity
test_connectivity() {
    print_info "Testing HTTP connectivity..."
    
    EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
        print_warning "No external IP available for testing"
        return
    fi
    
    print_info "Testing connectivity to http://$EXTERNAL_IP"
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 10 "http://$EXTERNAL_IP" | grep -q "GKE Multicluster Demo"; then
            print_success "HTTP connectivity test passed!"
        else
            print_warning "HTTP connectivity test failed or unexpected response"
        fi
    else
        print_warning "curl not available for connectivity testing"
    fi
}

# Display summary
display_summary() {
    print_info "=== Deployment Summary ==="
    
    EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo -e "${GREEN}Demo URL:${NC} http://$EXTERNAL_IP"
    else
        echo -e "${YELLOW}External IP:${NC} Pending (run this script again in a few minutes)"
    fi
    
    echo
    print_info "=== Useful Commands ==="
    echo "kubectl get pods -A"
    echo "kubectl get svc -A"
    echo "kubectl logs -n istio-system deployment/istiod"
    echo "kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
}

# Main execution
main() {
    print_info "Starting validation of GKE Multicluster deployment..."
    echo
    
    check_cluster_access
    echo
    check_gke_cluster
    echo
    check_istio
    echo
    check_nginx_demo
    echo
    test_connectivity
    echo
    display_summary
    
    print_success "Validation completed! 🎉"
}

# Run main function
main "$@"