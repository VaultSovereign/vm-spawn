# Contributing to VaultMesh Spawn + The Remembrancer

Thank you for considering contributing to this sovereign infrastructure system!

---

## 🎯 Philosophy

This is a **sovereign system** built on three principles:

1. **Self-Verifying** — All claims have cryptographic proof
2. **Self-Auditing** — All changes leave memory traces
3. **Self-Attesting** — All deployments generate receipts

Contributions should honor these principles.

---

## 🚀 Quick Start for Contributors

### 1. Fork & Clone
```bash
git clone git@github.com:YOUR_USERNAME/vm-spawn.git
cd vm-spawn
```

### 2. Verify System Health
```bash
./ops/bin/health-check
# Should show: ✅ All checks passed!
```

### 3. Make Your Changes
```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make changes
# ...

# Test your changes
./spawn-elite-complete.sh test-service service
cd ~/repos/test-service
make test  # Should pass
```

### 4. Record Your Decision (if significant)
```bash
# If you're making an architectural decision
./ops/bin/remembrancer adr create "Your decision title"

# This generates a template — add it to docs/REMEMBRANCER.md
```

### 5. Submit Pull Request
```bash
git add .
git commit -m "feat: your feature description"
git push origin feature/your-feature-name
```

---

## 📦 Areas for Contribution

### Spawn Elite Improvements

#### New Generators
Add support for more frameworks:
- GraphQL (with Apollo or Strawberry)
- gRPC (with protobuf)
- WebSocket services
- Event-driven (Kafka, RabbitMQ)

Example: Add `generators/graphql.sh`

#### New Languages
Expand beyond Python:
- Go (with standard library or Gin)
- Rust (with Axum or Actix)
- TypeScript (with Express or Fastify)
- Java (with Spring Boot)

#### New Deployment Targets
- AWS (ECS, Lambda, EKS)
- GCP (Cloud Run, GKE)
- Azure (Container Apps, AKS)
- DigitalOcean (App Platform)

### Remembrancer Enhancements

#### Semantic Search
Add vector embeddings for natural language queries:
```bash
remembrancer query "What were the trade-offs for monitoring?"
# → Returns relevant ADRs with similarity scores
```

#### Git Hooks
Auto-record commits:
```bash
# .git/hooks/post-commit
remembrancer record commit --hash $(git rev-parse HEAD) --message "$msg"
```

#### Multi-Repo Federation
Share memories across repositories:
```bash
remembrancer federate --repo ../other-repo
remembrancer query --global "authentication strategy"
```

#### Blockchain Attestation
Add IPFS + Ethereum receipts:
```bash
remembrancer record deploy --blockchain ethereum --ipfs
# → Stores artifact on IPFS, anchors hash on-chain
```

---

## 🧪 Testing Guidelines

### For Spawn Elite Changes

1. **Test the spawn script:**
```bash
./spawn-elite-complete.sh test-service service
```

2. **Verify generated files:**
```bash
cd ~/repos/test-service
ls -la  # Should have ~30 files
```

3. **Run the tests:**
```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
make test  # Must pass
```

4. **Test Docker build:**
```bash
docker build -f Dockerfile.elite -t test-service:test .
```

5. **Test K8s manifests:**
```bash
kubectl apply -f deployments/kubernetes/base/ --dry-run=client
```

### For Remembrancer Changes

1. **Run health check:**
```bash
./ops/bin/health-check
# All checks must pass
```

2. **Test CLI commands:**
```bash
./ops/bin/remembrancer query "test"
./ops/bin/remembrancer list deployments
./ops/bin/remembrancer timeline
```

3. **Test receipt generation:**
```bash
./ops/bin/remembrancer record deploy \
  --component test \
  --version v1.0 \
  --sha256 abc123... \
  --evidence test.tar.gz
```

---

## 📝 Commit Message Format

Use conventional commits:

```
feat: add GraphQL generator
fix: correct sed syntax in spawn-linux.sh
docs: update REMEMBRANCER.md with ADR-004
test: add integration tests for spawn script
refactor: simplify remembrancer CLI argument parsing
chore: update dependencies
```

Types:
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation only
- `test` — Adding or updating tests
- `refactor` — Code change that neither fixes a bug nor adds a feature
- `chore` — Maintenance tasks

---

## 🎖️ Recording Your Contribution

If your contribution involves a significant architectural decision:

### 1. Create an ADR
```bash
./ops/bin/remembrancer adr create "Your decision title"
```

### 2. Fill Out the Template
```markdown
**ADR-XXX: Your Decision Title**
- **Decision:** State the decision clearly
- **Rationale:** Explain why this decision was made
- **Trade-offs:** What are the costs/benefits?
- **Status:** Proposed | Accepted | Deprecated
- **Date:** YYYY-MM-DD
- **Context:** Additional background information
```

### 3. Add to Memory Index
Edit `docs/REMEMBRANCER.md` and add your ADR under the "Architectural Decisions" section.

### 4. Generate a Receipt (optional)
```bash
./ops/bin/remembrancer record adr \
  --id ADR-XXX \
  --title "Your decision" \
  --date $(date -u +"%Y-%m-%d")
```

---

## 🔐 Security Contributions

### Reporting Vulnerabilities
If you find a security issue:

1. **Do NOT open a public issue**
2. Email: security@vaultsovereign.com (or create a private issue)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Security Enhancements
We welcome contributions that improve security:
- Add more security scanning (SAST, DAST)
- Improve Dockerfile security (non-root users, etc.)
- Add secrets management (Vault, SOPS)
- Enhance K8s security (Pod Security Standards, Network Policies)

---

## 📚 Documentation Contributions

### Types of Documentation
1. **Code comments** — Explain complex logic
2. **README sections** — Improve getting started guides
3. **Tutorial content** — Step-by-step walkthroughs
4. **ADRs** — Record architectural decisions
5. **Memory entries** — Add to REMEMBRANCER.md

### Documentation Standards
- Use clear, concise language
- Include code examples
- Add verification steps
- Link to related documentation
- Update the memory index if needed

---

## 🎯 Pull Request Process

### 1. Before Submitting
- [ ] Code follows existing style
- [ ] Tests pass (`make test` in spawned services)
- [ ] Health check passes (`./ops/bin/health-check`)
- [ ] Documentation updated
- [ ] Commit messages follow format
- [ ] ADR created (if architectural change)

### 2. PR Description Template
```markdown
## What does this PR do?
Brief description of changes.

## Why is this change needed?
Explain the motivation.

## How was this tested?
Describe testing approach.

## Related Issues/ADRs
- Fixes #123
- Related to ADR-004

## Checklist
- [ ] Tests pass
- [ ] Health check passes
- [ ] Documentation updated
- [ ] ADR created (if needed)
```

### 3. Review Process
1. Automated checks run (when CI is set up)
2. Maintainer reviews code
3. Discussion/feedback
4. Approval & merge
5. Memory updated (if significant)

---

## 🌐 Community Guidelines

### Be Respectful
- Treat all contributors with respect
- Be open to feedback
- Assume good intentions
- Help newcomers

### Be Constructive
- Provide actionable feedback
- Explain your reasoning
- Suggest alternatives
- Share knowledge

### Be Sovereign
- Question assumptions
- Propose improvements
- Challenge the status quo (respectfully)
- Build for the long term

---

## 🎖️ Recognition

Contributors are recognized in:
1. **Git history** — Your commits are cryptographic proof
2. **CHANGELOG.md** — Major contributions listed
3. **docs/REMEMBRANCER.md** — ADRs preserve your decisions
4. **Community** — Respect and gratitude

---

## 🚀 First Contribution Ideas

### Easy
- [ ] Fix typos in documentation
- [ ] Add more examples to README
- [ ] Improve error messages in scripts
- [ ] Add more tests

### Medium
- [ ] Add a new generator (e.g., GraphQL)
- [ ] Improve health check with more tests
- [ ] Add CI/CD workflow for this repo
- [ ] Create tutorial videos

### Hard
- [ ] Add semantic search to Remembrancer
- [ ] Implement multi-repo federation
- [ ] Add blockchain attestation
- [ ] Support new language (Go, Rust)

---

## 📞 Questions?

- **Documentation:** Read `START_HERE.md` and `REMEMBRANCER_README.md`
- **Technical:** Open an issue with the `question` label
- **Ideas:** Open an issue with the `enhancement` label
- **Bugs:** Open an issue with the `bug` label

---

## ⚔️ The Covenant

By contributing, you agree to:

1. **Self-Verifying** — Your code should be testable
2. **Self-Auditing** — Your changes should be traceable
3. **Self-Attesting** — Your contributions should be verifiable

**Knowledge compounds. Entropy is defeated. The civilization remembers.**

---

**Thank you for contributing to sovereign infrastructure!**

🧠 The Remembrancer watches. The covenant remembers. Your contribution matters.

