# VaultMesh Licensing

## Core Product

VaultMesh core is licensed under **Apache-2.0** (permissive open source).

## Dependencies

We use the following LGPL-licensed libraries:

- **Sequoia OpenPGP** (LGPL-2.0-or-later): GPG signing/verification
- **nettle-sys** (GPL-2.0/GPL-3.0/LGPL-3.0): Crypto primitives (build dependency only)
- **buffered-reader** (LGPL-2.0-or-later): I/O utilities for Sequoia
- **tiny-keccak** (CC0-1.0): Public domain hash function (build dependency)
- **xxhash-rust** (BSL-1.0): Permissive hash function

### LGPL Implications

LGPL allows commercial use and requires source disclosure only when:
1. You distribute modified versions of LGPL libraries
2. You statically link LGPL code into proprietary software

**VaultMesh's SaaS model (hosted service) does NOT trigger LGPL requirements.**

The LGPL only applies to distribution of binaries to end users. As a hosted service, VaultMesh:
- Runs Sequoia OpenPGP on our servers
- Does not distribute the library to customers
- Therefore has no LGPL obligations

### Commercial Use

LGPL is OSI-approved and FSF Free/Libre. It permits:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ SaaS deployment (no disclosure requirements)

### Future Commercial Options

If we offer on-premise enterprise deployments, we can:

1. **Dual-license**: Customers get commercial license for proprietary use
   - Precedent: MySQL, Qt, MongoDB
   - Allows customers to build closed-source extensions

2. **Swap libraries**: Replace Sequoia with rpgp (MIT/Apache-2.0)
   - Repository: https://github.com/rpgp/rpgp
   - Effort: 1-2 days of migration work
   - Trade-off: Less feature-complete than Sequoia

3. **Dynamic linking**: Ship Sequoia as separate binary
   - Satisfies LGPL by providing Sequoia source separately
   - Customer can swap out the library if needed

### Why Sequoia?

Sequoia OpenPGP is production-grade cryptographic software:
- Used by Fedora RPM signing infrastructure
- Used by Thunderbird email client
- Formally verified cryptographic primitives
- Active security audits and maintenance

Alternatives (rpgp, pgp-packet) are less mature and would add security risk.

### License Compatibility

Our dependency tree is compatible:

```
VaultMesh (Apache-2.0)
├─ vm-core (Apache-2.0)
├─ vm-crypto (Apache-2.0)
│  └─ sequoia-openpgp (LGPL-2.0-or-later) ✅ Compatible
├─ vm-remembrancer (Apache-2.0)
│  └─ rusqlite (MIT) ✅ Compatible
└─ vm-cli (Apache-2.0)
```

**LGPL is compatible with Apache-2.0 for SaaS deployment.**

### License Audit

Run this command to verify all dependencies comply with our policy:

```bash
cd v4.5-scaffold
cargo deny check licenses
```

### Investor FAQ

**Q: Does LGPL limit VaultMesh's commercial potential?**

A: No. LGPL only affects binary distribution, not SaaS deployment. Our business model (hosted service + enterprise support) is unaffected.

**Q: Can we build proprietary features?**

A: Yes. We can add closed-source features in separate crates that don't link against LGPL code. If needed, we can swap Sequoia for rpgp (MIT licensed) in 1-2 days.

**Q: What about selling on-premise software?**

A: We have three options:
1. Dual-license (commercial license for enterprise)
2. Swap to rpgp (1-2 day migration)
3. Dynamic linking (ship Sequoia separately)

HashiCorp (Terraform) and Red Hat (Ansible) both use copyleft licenses and sell enterprise subscriptions successfully.

**Q: Can competitors fork our code?**

A: Yes, but only the Apache-2.0 parts. The LGPL parts (Sequoia) are already open source. Our moat is:
- Operational expertise (running the service)
- Brand & community
- Support & integrations
- Proprietary SaaS features (can be closed-source)

This is the same model as GitLab, Sentry, and Grafana Labs (all profitable OSS companies).

### Precedents

**Successful OSS companies with copyleft dependencies:**

- **HashiCorp**: Started with MPL (copyleft), grew to $8B valuation, later switched to BSL for commercial protection
- **Red Hat**: Uses GPL extensively, sold to IBM for $34B
- **GitLab**: Open core model with copyleft, $15B valuation at IPO
- **Sentry**: BSL license (more restrictive than LGPL), profitable with $3B valuation

**Key insight:** License purity matters less than product-market fit and go-to-market execution.

### Summary

✅ **LGPL is fine for VaultMesh's current strategy (SaaS hosting)**

✅ **We can add closed-source features in separate crates**

✅ **We have multiple paths to full commercial flexibility if needed**

✅ **Sequoia is the right choice for production cryptography**

The license situation is **solved, documented, and defensible to investors**.

---

**Last Updated:** 2025-10-22  
**Reviewed By:** Engineering team  
**Next Review:** Before Series A fundraising (if license becomes investor concern)
