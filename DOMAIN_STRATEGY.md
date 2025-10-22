# 🌐 VaultMesh Domain Strategy

**Adopted:** 2025-10-22  
**Status:** ✅ Active

---

## Executive Summary

VaultMesh operates under a **dual-domain model** separating governance from operations:

- **vaultmesh.org** → Governance, standards, compliance, community (civilization ledger)
- **vaultmesh.cloud** → Operational platform, APIs, console, workloads (production service)

**Current Launch:** Aurora is deployed on **vaultmesh.cloud**

---

## Domain Roles

### vaultmesh.org — Civilization Ledger

**Purpose:** Neutral governance, standards, and public trust

**Subdomains:**
- `www.vaultmesh.org` → Marketing, blog, research
- `docs.vaultmesh.org` → Technical documentation
- `governance.vaultmesh.org` → Charters, bylaws, proposals
- `compliance.vaultmesh.org` → AI RMF/ISO annexes, audit packs
- `research.vaultmesh.org` → Papers, case studies
- `status.vaultmesh.org` → Public status (mirror)

**Email:**
- `*@vaultmesh.org` → Primary communications
- SPF/DMARC/DKIM + MTA-STS + BIMI
- Security: DNSSEC, CAA, HSTS preload

**Infrastructure:**
- Static site (MkDocs/Docusaurus)
- CloudFlare Pages or S3 + CloudFront
- Read-only, high availability

---

### vaultmesh.cloud — Operational Platform

**Purpose:** Live production service for Aurora and future products

**Subdomains:**
- `api.vaultmesh.cloud` → Public API gateway (Aurora API)
- `console.vaultmesh.cloud` → Tenant UI (Aurora Console)
- `grafana.vaultmesh.cloud` → Observability dashboard (auth-protected)
- `prometheus.vaultmesh.cloud` → Metrics endpoint (auth-protected)
- `ledger.vaultmesh.cloud` → Read-only receipts explorer
- `status.vaultmesh.cloud` → Operations status page
- `idp.vaultmesh.cloud` → SSO/OIDC identity provider
- `*.tenant.vaultmesh.cloud` → Per-tenant namespaces

**Infrastructure:**
- AWS EKS (aurora-staging, aurora-production)
- Route53 latency-based routing with health checks
- WAF + CloudFront for `console` and `api`
- ACM wildcard certificate (`*.vaultmesh.cloud`)
- DNSSEC, CAA records limiting to AWS ACM

---

## Why This Split Works

| Aspect | Benefit |
|--------|---------|
| **Brand Clarity** | .org signals neutrality/stewardship; .cloud signals live service |
| **Trust & Sales** | Auditors trust .org governance; users target .cloud endpoints |
| **Future-Proof** | When foundation/DAO emerges, .org is ready; .cloud scales multi-tenant |
| **SEO/UX** | .cloud performs better for compute/orchestration platforms |
| **Operational Simplicity** | All K8s ingress, APIs, dashboards under single DNS zone |

---

## Aurora Launch Configuration

### Production Endpoints

```
Aurora API:      https://api.vaultmesh.cloud
Aurora Console:  https://console.vaultmesh.cloud
Grafana:         https://grafana.vaultmesh.cloud
Prometheus:      https://prometheus.vaultmesh.cloud
Ledger Explorer: https://ledger.vaultmesh.cloud
Status Page:     https://status.vaultmesh.cloud
```

### Week 1 EKS Integration

```bash
# Update ingress annotations
kubectl annotate ingress aurora-api \
  external-dns.alpha.kubernetes.io/hostname=api.vaultmesh.cloud

kubectl annotate ingress aurora-console \
  external-dns.alpha.kubernetes.io/hostname=console.vaultmesh.cloud

# Update Grafana ingress
kubectl annotate ingress grafana \
  external-dns.alpha.kubernetes.io/hostname=grafana.vaultmesh.cloud
```

---

## DNS Configuration

### Route53 Setup

See: [ops/aws/route53-vaultmesh-cloud.tf](ops/aws/route53-vaultmesh-cloud.tf)

**Key records:**
- A/AAAA: `api`, `console`, `ledger` → ALB/CloudFront
- CNAME: `grafana`, `prometheus` → K8s LoadBalancers
- CAA: Limit to Amazon ACM
- MX: SES inbound
- TXT: SPF, DMARC

### TLS Certificates

**Global (CloudFront):**
```bash
# ACM in us-east-1
aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region us-east-1
```

**Regional (ALB):**
```bash
# ACM in eu-west-1
aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region eu-west-1
```

---

## Security Configuration

### CAA Records

```
vaultmesh.cloud. IN CAA 0 issue "amazon.com"
vaultmesh.cloud. IN CAA 0 issuewild "amazon.com"
vaultmesh.cloud. IN CAA 0 issue "letsencrypt.org"
vaultmesh.cloud. IN CAA 0 iodef "mailto:security@vaultmesh.cloud"
```

### Email Security

**SPF:**
```
v=spf1 include:amazonses.com ~all
```

**DMARC:**
```
v=DMARC1; p=quarantine; rua=mailto:dmarc@vaultmesh.cloud; fo=1
```

**DKIM:**
```bash
# Generate via AWS SES
aws ses verify-domain-dkim --domain vaultmesh.cloud
```

---

## Implementation Timeline

### Phase 1: Aurora Launch (Current)

- [x] Register vaultmesh.cloud
- [x] Configure Route53 hosted zone
- [x] Request ACM certificates
- [ ] Deploy Aurora to EKS with vaultmesh.cloud ingress
- [ ] Configure CloudFront for console.vaultmesh.cloud
- [ ] Set up Grafana/Prometheus with auth at vaultmesh.cloud subdomains
- [ ] Deploy status page

**Target:** Week 1 completion (Nov 18)

### Phase 2: Governance Site (Q4 2025)

- [ ] Register vaultmesh.org
- [ ] Deploy static docs site
- [ ] Migrate governance content
- [ ] Configure email @vaultmesh.org
- [ ] Enable DNSSEC

### Phase 3: Foundation (2026)

- [ ] Transfer vaultmesh.org to foundation entity
- [ ] Multi-sig DNS control
- [ ] Compliance portal at compliance.vaultmesh.org
- [ ] Public research repository

---

## Copy-Ready Decision Blurb

> "VaultMesh operates under a dual-domain model:
> **vaultmesh.org** for governance, standards, and public documentation;
> **vaultmesh.cloud** for the live platform (console, APIs, observability, and tenant workloads).
> This separation preserves neutrality and audit trust while keeping product endpoints crisp and scalable."

---

## Taglines & Messaging

### Aurora Launch

```
Aurora by VaultMesh
Available at vaultmesh.cloud

The sovereign routing layer for AI and DePIN compute.
```

### Platform Positioning

```
VaultMesh.Cloud — launch, route, and verify sovereign AI workloads.
```

---

## Infrastructure as Code

### Terraform Modules

- `ops/aws/route53-vaultmesh-cloud.tf` — DNS records
- `ops/aws/cloudfront-console.tf` — Console CDN (coming)
- `ops/aws/alb-aurora-api.tf` — API load balancer (coming)

### GitHub Actions

- `.github/workflows/deploy-staging-eks.yml` — Auto-deploys to vaultmesh.cloud

---

## Support & Operations

### Email Addresses

**Production:**
- `noreply@vaultmesh.cloud` — System notifications
- `ops@vaultmesh.cloud` — Incident alerts
- `support@vaultmesh.cloud` — User support
- `security@vaultmesh.cloud` — Security reports

**Governance:**
- `governance@vaultmesh.org` — Policy inquiries
- `compliance@vaultmesh.org` — Audit requests
- `research@vaultmesh.org` — Academic collaboration

---

## Cost Estimate

### vaultmesh.cloud (Production)

```
Route53 Hosted Zone:    $0.50/month
Health Checks (2):      $1.00/month
ACM Certificates:       Free
CloudFront:             ~$5-50/month (usage-based)
EKS ALB:                ~$20/month
Total:                  ~$25-75/month base + traffic
```

### vaultmesh.org (Governance)

```
Route53 Hosted Zone:    $0.50/month
CloudFlare Pages:       Free
S3 + CloudFront:        ~$1-5/month
Total:                  ~$2-6/month
```

---

## Verification Commands

```bash
# Check DNS propagation
dig api.vaultmesh.cloud +short
dig console.vaultmesh.cloud +short

# Verify TLS
openssl s_client -connect api.vaultmesh.cloud:443 -servername api.vaultmesh.cloud

# Check CAA
dig CAA vaultmesh.cloud +short

# Test email security
dig TXT vaultmesh.cloud +short
dig TXT _dmarc.vaultmesh.cloud +short
```

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-22 | Adopt dual-domain model | Separate governance from operations |
| 2025-10-22 | Launch Aurora on .cloud | SaaS positioning, operational clarity |
| 2025-10-22 | Reserve .org for foundation | Future-proof for governance entity |

---

## 🜂 Covenant Seal

```
vaultmesh.org  → The civilization ledger (governance)
vaultmesh.cloud → The production platform (operations)

Aurora launches at vaultmesh.cloud.
Truth is operational. Law is executable.
```

**Astra inclinant, sed non obligant.**

---

**Last Updated:** 2025-10-22  
**Owner:** VaultMesh Operations  
**Next Review:** Q1 2026 (foundation planning)
