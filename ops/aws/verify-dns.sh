#!/usr/bin/env bash
# Quick DNS verification script for vaultmesh.cloud
set -euo pipefail

echo "🌐 VaultMesh.Cloud DNS Verification"
echo "====================================="
echo ""

# Check DNS propagation
echo "1️⃣ Checking DNS propagation..."
NS_SERVERS=$(dig NS vaultmesh.cloud +short 2>/dev/null || echo "")

if [ -z "$NS_SERVERS" ]; then
  echo "⏳ DNS not propagated yet (wait 15-30 minutes)"
  echo "   Name servers need time to update globally"
  exit 1
else
  echo "✅ DNS propagated! Name servers:"
  echo "$NS_SERVERS" | sed 's/^/   /'
fi

echo ""

# Check if hosted zone exists
echo "2️⃣ Checking Route53 hosted zone..."
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='vaultmesh.cloud.'].Id" --output text 2>/dev/null || echo "")

if [ -z "$ZONE_ID" ]; then
  echo "⚠️  Route53 hosted zone not created yet"
  echo "   Run: aws route53 create-hosted-zone --name vaultmesh.cloud --caller-reference \"\$(date +%s)\""
  exit 1
else
  echo "✅ Hosted zone exists: $ZONE_ID"
fi

echo ""

# Check ACM certificates
echo "3️⃣ Checking ACM certificates..."

# Regional cert
REGIONAL_CERT=$(aws acm list-certificates --region eu-west-1 --query "CertificateSummaryList[?DomainName=='*.vaultmesh.cloud'].{Arn:CertificateArn,Status:Status}" --output text 2>/dev/null || echo "")

if [ -z "$REGIONAL_CERT" ]; then
  echo "⚠️  Regional certificate (eu-west-1) not requested yet"
  echo "   Run: aws acm request-certificate --domain-name '*.vaultmesh.cloud' --validation-method DNS --region eu-west-1"
else
  echo "✅ Regional certificate:"
  echo "$REGIONAL_CERT" | sed 's/^/   /'
fi

# Global cert
GLOBAL_CERT=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='*.vaultmesh.cloud'].{Arn:CertificateArn,Status:Status}" --output text 2>/dev/null || echo "")

if [ -z "$GLOBAL_CERT" ]; then
  echo "⚠️  Global certificate (us-east-1) not requested yet"
  echo "   Run: aws acm request-certificate --domain-name '*.vaultmesh.cloud' --validation-method DNS --region us-east-1"
else
  echo "✅ Global certificate:"
  echo "$GLOBAL_CERT" | sed 's/^/   /'
fi

echo ""

# Check security records
echo "4️⃣ Checking security records..."

# CAA
CAA_RECORDS=$(dig vaultmesh.cloud CAA +short 2>/dev/null || echo "")
if [ -z "$CAA_RECORDS" ]; then
  echo "⚠️  CAA records not configured"
else
  echo "✅ CAA records:"
  echo "$CAA_RECORDS" | sed 's/^/   /'
fi

# SPF
SPF_RECORDS=$(dig vaultmesh.cloud TXT +short 2>/dev/null | grep spf || echo "")
if [ -z "$SPF_RECORDS" ]; then
  echo "⚠️  SPF record not configured"
else
  echo "✅ SPF record:"
  echo "$SPF_RECORDS" | sed 's/^/   /'
fi

# DMARC
DMARC_RECORDS=$(dig _dmarc.vaultmesh.cloud TXT +short 2>/dev/null || echo "")
if [ -z "$DMARC_RECORDS" ]; then
  echo "⚠️  DMARC record not configured"
else
  echo "✅ DMARC record:"
  echo "$DMARC_RECORDS" | sed 's/^/   /'
fi

echo ""
echo "====================================="
echo "📊 Summary"
echo ""
echo "DNS Propagation:    ${NS_SERVERS:+✅}${NS_SERVERS:-⏳}"
echo "Route53 Zone:       ${ZONE_ID:+✅}${ZONE_ID:-⚠️}"
echo "ACM Regional:       ${REGIONAL_CERT:+✅}${REGIONAL_CERT:-⚠️}"
echo "ACM Global:         ${GLOBAL_CERT:+✅}${GLOBAL_CERT:-⚠️}"
echo "Security Records:   ${CAA_RECORDS:+✅}${CAA_RECORDS:-⚠️}"
echo ""

if [ -n "$NS_SERVERS" ] && [ -n "$ZONE_ID" ] && [ -n "$REGIONAL_CERT" ] && [[ "$REGIONAL_CERT" == *"ISSUED"* ]]; then
  echo "🚀 Ready for EKS deployment!"
  echo "   Next: eksctl create cluster -f eks-aurora-staging.yaml"
elif [ -n "$NS_SERVERS" ] && [ -n "$ZONE_ID" ]; then
  echo "⏳ Waiting for ACM certificates to issue (5-30 minutes)"
  echo "   Check again: ./ops/aws/verify-dns.sh"
elif [ -n "$NS_SERVERS" ]; then
  echo "📋 Next: Deploy Route53 records"
  echo "   See: IMMEDIATE_ACTIONS.md Step 2"
else
  echo "⏳ Waiting for DNS propagation (15-30 minutes)"
  echo "   Check again in 15 minutes"
fi

echo ""
