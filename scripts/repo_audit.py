#!/usr/bin/env python3
from __future__ import annotations
import json, os, subprocess
from pathlib import Path
from datetime import datetime

def sh(cmd: str):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

def has(p: str) -> bool: return Path(p).exists()
def mb(p: Path) -> float: return p.stat().st_size/1024/1024

def section(t): print(f"\n## {t}\n")

print(f"# vm-spawn — Complete Repo Report\nGenerated: {datetime.utcnow().isoformat()}Z\n")

# Repository
section("Repository")
_, rev, _ = sh("git rev-parse --short HEAD")
_, br, _  = sh("git rev-parse --abbrev-ref HEAD")
_, url, _ = sh("git config --get remote.origin.url")
_, sig, _ = sh("git log -1 --show-signature --pretty=fuller")
signed = ("Good signature" in sig) or ("gpg: Signature made" in sig)
print(f"- Commit: `{rev}` on `{br}`\n- Remote: `{url}`\n- Last commit signed: **{'yes' if signed else 'no'}**")

# Governance
section("Governance & Docs")
must = ["LICENSE","CODEOWNERS","SECURITY.md","CONTRIBUTING.md",".pre-commit-config.yaml"]
for f in must: print(f"- {f}: {'✅' if has(f) else '❌'}")
wfs = [".github/workflows/ci.yml",".github/workflows/security.yml",".github/workflows/release.yml",".github/workflows/scorecard.yml",".github/workflows/audit.yml"]
for f in wfs: print(f"- {f}: {'✅' if has(f) else '❌'}")

# Structure
section("Structure & Layout")
paths = ["packages/vaultmesh_psi","services/psi-field","infra/docker","infra/k8s","docs","scripts"]
for p in paths: print(f"- {p}/: {'✅' if has(p) else '❌'}")

# Hygiene
section("Hygiene (large files & archives)")
large=[]; archives=[]
for p in Path(".").rglob("*"):
    if p.is_file():
        try:
            if mb(p) > 2.0: large.append((mb(p), str(p)))
            if p.suffix.lower() in (".zip",".tar",".gz",".whl",".egg"): archives.append(str(p))
        except FileNotFoundError:
            pass
print("- Large files >2MB:", len(large))
for sz,fp in sorted(large, reverse=True)[:12]: print(f"  - {fp} — {sz:.2f} MB")
print("- Archives tracked:", len(archives))
for fp in archives[:12]: print(f"  - {fp}")

# Lint/Test/Coverage (non-fatal)
section("Lint, Test, Coverage (best effort)")
rc,out,err = sh("pytest -q --maxfail=1 --disable-warnings || true"); print("**pytest**\n```\n"+(out or err)+"\n```")
rc,out,err = sh("coverage run -m pytest -q || true && coverage xml -o coverage.xml || true && coverage report || true"); print("**coverage**\n```\n"+(out or err)+"\n```")
rc,out,err = sh("bandit -r packages/vaultmesh_psi -f json || true")
try:
    j = json.loads(out) if out else {}
    issues = len(j.get("results",[])) if "results" in j else 0
    print(f"- Bandit issues: **{issues}** (see logs)")
except Exception:
    print("- Bandit: no parse")

# Dependency audit
section("Dependency Audit (pip-audit)")
rc,out,err = sh("pip-audit -f json || true")
if out:
    try:
        vulns = json.loads(out)
        count = sum(len(p.get('vulns',[])) for p in vulns)
        print(f"- Vulnerabilities: **{count}**")
    except Exception:
        print("- Could not parse pip-audit output")
else:
    print("- No pip-audit output")

# SBOM
section("SBOM")
rc,_,_ = sh("cyclonedx-bom -o sbom.json || true")
print(f"- SBOM generated: {'✅' if Path('sbom.json').exists() else '❌'}")

# Size & Languages
section("Size & Languages")
rc,out,err = sh("pygount --format=summary . || true")
print("```\n"+(out or err)+"\n```")

# Badges
section("Badges in README")
readme = Path("README.md").read_text(encoding="utf-8", errors="ignore") if has("README.md") else ""
def badge(snippet): return ('✅' if snippet in readme else '❌')
print(f"- CI badge: {badge('actions/workflows/ci.yml/badge.svg')}")
print(f"- Security badge: {badge('actions/workflows/security.yml/badge.svg')}")
print(f"- Scorecard badge: {badge('securityscorecards.dev')}")
print(f"- Release badge: {badge('img.shields.io/github/v/release')}")

