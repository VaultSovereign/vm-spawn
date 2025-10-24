#!/bin/bash
set -e

# VaultMesh Cloudflare DNS Setup
# Configures DNS records for vaultmesh.cloud infrastructure domain

# Cloudflare credentials (from environment or config file)
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-8276372d1df87af19b7b595f1c419219}"  # vaultmesh.cloud zone ID (public)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 VaultMesh Cloudflare DNS Setup${NC}"
echo "=================================="
echo ""

# Check for required credentials
if [ -z "$CF_API_TOKEN" ]; then
  echo -e "${RED}❌ CF_API_TOKEN environment variable not set${NC}"
  echo ""
  echo "Set it with:"
  echo -e "  ${YELLOW}export CF_API_TOKEN='your-cloudflare-api-token'${NC}"
  echo ""
  echo "Or store in ~/.vaultmesh/cloudflare.env:"
  echo -e "  ${YELLOW}mkdir -p ~/.vaultmesh${NC}"
  echo -e "  ${YELLOW}echo 'export CF_API_TOKEN=\"your-token\"' > ~/.vaultmesh/cloudflare.env${NC}"
  echo -e "  ${YELLOW}chmod 600 ~/.vaultmesh/cloudflare.env${NC}"
  echo -e "  ${YELLOW}source ~/.vaultmesh/cloudflare.env${NC}"
  exit 1
fi
echo ""

# Check if kubectl is connected
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}❌ Not connected to Kubernetes cluster${NC}"
  echo "Run: gcloud container clusters get-credentials vaultmesh-minimal --region us-central1 --project vm-spawn"
  exit 1
fi

# Get Ingress IP
echo -e "${YELLOW}Getting LoadBalancer IP from Kubernetes Ingress...${NC}"
INGRESS_IP=$(kubectl get ingress vaultmesh-ingress -n vaultmesh -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
  echo -e "${RED}❌ Ingress not found or no IP assigned yet${NC}"
  echo "Make sure:"
  echo "  1. Ingress is deployed: kubectl apply -f k8s/ingress.yaml"
  echo "  2. Wait 2-3 minutes for LoadBalancer to provision"
  echo "  3. Check status: kubectl get ingress -n vaultmesh"
  exit 1
fi

echo -e "${GREEN}✓ Found Ingress IP: $INGRESS_IP${NC}"
echo ""

# Function to create DNS record
create_dns_record() {
  local type=$1
  local name=$2
  local content=$3

  echo -e "${YELLOW}Creating $type record: $name.vaultmesh.cloud → $content${NC}"

  response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\": \"$type\",
      \"name\": \"$name\",
      \"content\": \"$content\",
      \"ttl\": 300,
      \"proxied\": false
    }")

  success=$(echo "$response" | jq -r '.success')

  if [ "$success" = "true" ]; then
    record_id=$(echo "$response" | jq -r '.result.id')
    echo -e "${GREEN}✓ Created: $name.vaultmesh.cloud (ID: ${record_id:0:8}...)${NC}"
  else
    # Check if it's a duplicate error (already exists)
    error_code=$(echo "$response" | jq -r '.errors[0].code')
    if [ "$error_code" = "81057" ]; then
      echo -e "${YELLOW}⚠ Record already exists: $name.vaultmesh.cloud${NC}"
    else
      error_msg=$(echo "$response" | jq -r '.errors[0].message')
      echo -e "${RED}❌ Failed: $error_msg${NC}"
    fi
  fi
}

# Create DNS records
echo "Creating DNS records..."
echo ""

# Main API endpoint (A record)
create_dns_record "A" "api" "$INGRESS_IP"

# Service subdomains (CNAMEs)
create_dns_record "CNAME" "psi-field" "api.vaultmesh.cloud"
create_dns_record "CNAME" "scheduler" "api.vaultmesh.cloud"
create_dns_record "CNAME" "aurora" "api.vaultmesh.cloud"

echo ""
echo -e "${GREEN}✅ DNS setup complete!${NC}"
echo ""
echo "Verifying DNS propagation (this may take 1-2 minutes)..."
echo ""

# Wait for DNS propagation
sleep 10

# Verify DNS
echo "Testing DNS resolution:"
for subdomain in api psi-field scheduler aurora; do
  result=$(dig +short ${subdomain}.vaultmesh.cloud @1.1.1.1 | tail -1)
  if [ -n "$result" ]; then
    echo -e "  ${GREEN}✓${NC} ${subdomain}.vaultmesh.cloud → $result"
  else
    echo -e "  ${YELLOW}⚠${NC} ${subdomain}.vaultmesh.cloud → (propagating...)"
  fi
done

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Wait 5-10 minutes for SSL certificates to provision"
echo "2. Check cert status: kubectl get managedcertificate -n vaultmesh"
echo "3. Test endpoints:"
echo "   curl https://psi-field.vaultmesh.cloud/health"
echo "   curl https://scheduler.vaultmesh.cloud/health"
echo "4. Update Analytics .env.local with production URLs"
echo ""
echo -e "${GREEN}🜂 Solve et Coagula${NC}"
