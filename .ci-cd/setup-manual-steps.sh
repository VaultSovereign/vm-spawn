#!/bin/bash
# VaultMesh CI/CD - Manual Setup Completion Script
# This script provides commands to complete the Workload Identity Federation setup
# Run this after the OIDC provider has been created via Google Cloud Console

set -e

PROJECT=vm-spawn
POOL_ID=gh-oidc-pool
PROVIDER_ID=github
DEPLOY_SA="vaultmesh-deployer@$PROJECT.iam.gserviceaccount.com"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')

echo "🔧 VaultMesh CI/CD Setup - Manual Steps"
echo "========================================"
echo ""
echo "✅ Already Completed:"
echo "  - Service Account: $DEPLOY_SA"
echo "  - IAM Roles: artifactregistry.writer, container.clusterViewer, logging.logWriter"
echo "  - Kubernetes RBAC: deployer-edit role in vaultmesh namespace"
echo "  - Workload Identity Pool: $POOL_ID"
echo ""

# Step 1: Check if provider exists
echo "Step 1: Checking OIDC Provider Status..."
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --project="$PROJECT" \
    --location=global \
    --workload-identity-pool="$POOL_ID" &>/dev/null; then

  echo "✅ OIDC Provider '$PROVIDER_ID' exists"

  # Get provider resource name
  PROVIDER_NAME=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --project="$PROJECT" \
    --location=global \
    --workload-identity-pool="$POOL_ID" \
    --format="value(name)")

  echo "   Resource Name: $PROVIDER_NAME"
  echo ""

else
  echo "❌ OIDC Provider not found"
  echo ""
  echo "🔧 Manual Action Required:"
  echo "   1. Go to: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=$PROJECT"
  echo "   2. Click on pool: $POOL_ID"
  echo "   3. Click 'Add Provider'"
  echo "   4. Configure:"
  echo "      - Provider type: OpenID Connect (OIDC)"
  echo "      - Provider name: $PROVIDER_ID"
  echo "      - Issuer: https://token.actions.githubusercontent.com"
  echo "      - Audiences: Default"
  echo "      - Attribute mapping:"
  echo "          google.subject = assertion.sub"
  echo "          attribute.repository = assertion.repository"
  echo "          attribute.actor = assertion.actor"
  echo "   5. Click 'Save'"
  echo ""
  echo "   After creating, run this script again."
  exit 1
fi

# Step 2: Bind GitHub repo to service account
echo "Step 2: Configuring Service Account Binding..."
echo ""
read -p "Enter your GitHub repository (format: owner/repo-name): " GITHUB_REPO

if [[ -z "$GITHUB_REPO" ]]; then
  echo "❌ Repository name required"
  exit 1
fi

echo "Binding repository $GITHUB_REPO to $DEPLOY_SA..."

# Allow the specific GitHub repo to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA" \
  --project="$PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_REPO" \
  --role="roles/iam.workloadIdentityUser"

echo "✅ Service account binding complete"
echo ""

# Step 3: Display GitHub Secrets
echo "Step 3: GitHub Repository Secrets Configuration"
echo "================================================"
echo ""
echo "Add these secrets to your GitHub repository:"
echo "  Repository → Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "Secret 1: GCP_WIF_PROVIDER"
echo "  Value:"
echo "  $PROVIDER_NAME"
echo ""
echo "Secret 2: GCP_DEPLOYER_SA"
echo "  Value:"
echo "  $DEPLOY_SA"
echo ""

# Step 4: Verify setup
echo "Step 4: Verification"
echo "===================="
echo ""
echo "✅ Checking configuration..."

# Verify IAM binding
echo "IAM Policy for $DEPLOY_SA:"
gcloud iam service-accounts get-iam-policy "$DEPLOY_SA" \
  --project="$PROJECT" \
  --format="table(bindings.role,bindings.members)" | head -10

echo ""

# Verify Kubernetes RBAC
echo "Kubernetes RBAC:"
kubectl get role deployer-edit -n vaultmesh -o wide
kubectl get rolebinding deployer-edit-binding -n vaultmesh -o yaml | grep -A 3 "subjects:"

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Copy .github-workflows-deploy.yaml to your repo:"
echo "      mkdir -p .github/workflows"
echo "      cp ci-cd/.github-workflows-deploy.yaml .github/workflows/deploy.yaml"
echo ""
echo "   2. Ensure your repository has this structure:"
echo "      services/"
echo "        ├── psi-field/"
echo "        │   ├── Dockerfile"
echo "        │   └── k8s/*.yaml"
echo "        ├── scheduler/"
echo "        ├── aurora-router/"
echo "        ├── aurora-intelligence/"
echo "        └── vaultmesh-analytics/"
echo ""
echo "   3. Commit and push to main branch"
echo ""
echo "   4. Monitor deployment:"
echo "      Repository → Actions tab"
echo ""
echo "🎉 You're ready to deploy!"
