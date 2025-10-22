#!/usr/bin/env bash
# Setup AWS IAM OIDC role for GitHub Actions
# Run this once to configure GitHub → AWS trust

set -euo pipefail

# Configuration
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
GITHUB_ORG="${GITHUB_ORG:-VaultSovereign}"
GITHUB_REPO="${GITHUB_REPO:-vm-spawn}"
ROLE_NAME="GitHubOIDC-Aurora"
AWS_REGION="${AWS_REGION:-eu-west-1}"

echo "🔐 Setting up GitHub Actions OIDC for AWS"
echo "  Account: $AWS_ACCOUNT_ID"
echo "  Org/Repo: $GITHUB_ORG/$GITHUB_REPO"
echo "  Role: $ROLE_NAME"
echo ""

# 1. Create OIDC provider (if not exists)
echo "1️⃣ Creating OIDC provider..."
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null; then
  echo "  ✅ OIDC provider already exists"
else
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
  echo "  ✅ OIDC provider created"
fi

# 2. Create trust policy
echo "2️⃣ Creating trust policy..."
cat > /tmp/trust-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
JSON

# 3. Create IAM role
echo "3️⃣ Creating IAM role..."
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
  echo "  ⚠️  Role exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file:///tmp/trust-policy.json
else
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --description "GitHub Actions OIDC for Aurora deployments"
  echo "  ✅ Role created"
fi

# 4. Attach policies
echo "4️⃣ Attaching policies..."

# EKS permissions
cat > /tmp/eks-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
JSON

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "EKSAccess" \
  --policy-document file:///tmp/eks-policy.json

# S3 permissions for ledger snapshots
cat > /tmp/s3-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aurora-staging-ledger-*",
        "arn:aws:s3:::aurora-staging-ledger-*/*"
      ]
    }
  ]
}
JSON

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "S3LedgerAccess" \
  --policy-document file:///tmp/s3-policy.json

echo "  ✅ Policies attached"

# 5. Output summary
echo ""
echo "✅ OIDC setup complete!"
echo ""
echo "📋 Add this secret to your GitHub repo:"
echo "   AWS_ACCOUNT_ID = $AWS_ACCOUNT_ID"
echo ""
echo "🔗 Role ARN:"
echo "   arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "🚀 GitHub Actions can now deploy to EKS without long-lived credentials"
