#!/usr/bin/env python3
"""
Tem, Guardian of Remembrance — VaultMesh Directory Covenant Enforcer
Prevents organizational entropy through automated structure validation.
"""
import hashlib
import os
import sys
import json
import fnmatch
from pathlib import Path

ROOT = Path.cwd()
ARCHIVE_PREFIX = "archive" + os.sep
SKIP_DIRS = {".git", ".github", ".venv", "node_modules", "__pycache__", "dist", "logs", "out"}
COVENANT_PATH = Path(".vaultmesh/covenant.yaml")

# Allowlist for root markdown files (from covenant)
ALLOWED_ROOT = {
    "README.md", "START_HERE.md", "LICENSE", "SECURITY.md", "AGENTS.md",
    "CONTRIBUTING.md", "CHANGELOG.md", "VERSION_TIMELINE.md", "STATUS.md",
    "SOVEREIGN_LORE_CODEX_V1.md", "PROPOSAL_9_9_EXCELLENCE.md",
    "DIRECTORY_ASSESSMENT_REPORT.md"
}

def sha256(path: Path) -> str:
    """Compute SHA256 hash of file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def walk_files():
    """Walk repository files, skipping ignored directories."""
    for root_dir, subdirs, files in os.walk(ROOT):
        rel_dir = Path(root_dir).relative_to(ROOT)

        # Prune skip dirs
        parts = rel_dir.parts
        if any(p in SKIP_DIRS for p in parts) or str(rel_dir).startswith(".git"):
            subdirs[:] = []
            continue

        for f in files:
            file_path = rel_dir / f if str(rel_dir) != "." else Path(f)

            # Skip covenant itself
            if file_path == COVENANT_PATH:
                yield file_path, None
                continue

            full_path = ROOT / file_path
            if full_path.is_file():
                yield file_path, sha256(full_path)

def count_root_markdown() -> tuple[int, list[str]]:
    """Count markdown files in root and return violators."""
    root_mds = [f for f in os.listdir(ROOT) if f.endswith(".md") and Path(f).is_file()]
    violators = [f for f in root_mds if f not in ALLOWED_ROOT]
    return len(root_mds), violators

def violation(msg: str, store: list):
    """Record violation for reporting."""
    store.append(msg)
    print(f"::error::{msg}")

def main():
    errors = []
    duplicates = {}
    outside_archive_by_hash = {}

    print("🜂 Tem Guardian initializing...")
    print(f"Covenant: {COVENANT_PATH}")
    print(f"Sacred Root Limit: 15 markdown files")
    print()

    # Collect file hashes
    for file_path, file_hash in walk_files():
        if file_hash is None:
            continue

        if file_hash not in duplicates:
            duplicates[file_hash] = []
        duplicates[file_hash].append(str(file_path))

        if not str(file_path).startswith(ARCHIVE_PREFIX):
            outside_archive_by_hash.setdefault(file_hash, []).append(str(file_path))

    # Rule 1: Duplicate content outside archive
    dup_count = 0
    for file_hash, paths in outside_archive_by_hash.items():
        if len(paths) > 1:
            violation(
                f"COVENANT BREACH: Duplicate content outside archive (hash={file_hash[:8]}...): {paths}",
                errors
            )
            dup_count += 1

    if dup_count > 0:
        print(f"⚠️  Found {dup_count} duplicate file groups outside archive")

    # Rule 2: Root markdown limit
    md_count, violators = count_root_markdown()
    if md_count > 15:
        violation(
            f"COVENANT BREACH: Root has {md_count} markdown files (>15 limit). "
            f"Move these to docs/ or archive/: {violators}",
            errors
        )
        print(f"⚠️  Root markdown excess: {md_count}/15")
    else:
        print(f"✅ Root markdown count: {md_count}/15")

    # Rule 3: Service structure consistency
    services_dir = ROOT / "services"
    if services_dir.is_dir():
        service_errors = 0
        for svc in sorted(services_dir.iterdir()):
            if not svc.is_dir():
                continue

            svc_name = svc.name

            # Check for required directories
            needs = ["src", "tests"]
            for need in needs:
                if not (svc / need).is_dir():
                    violation(
                        f"COVENANT BREACH: Service '{svc_name}' missing '{need}/' directory",
                        errors
                    )
                    service_errors += 1

            # Check for old 'test' dir
            if (svc / "test").is_dir():
                violation(
                    f"COVENANT BREACH: Service '{svc_name}' uses 'test/' — must be 'tests/' (plural)",
                    errors
                )
                service_errors += 1

        if service_errors > 0:
            print(f"⚠️  Service structure violations: {service_errors}")
        else:
            print("✅ Service structure compliant")

    # Rule 4: GCP/GKE canonicalization
    bad_paths = []
    legacy_globs = ["docs/gcp/**", "docs/gke/**", "deployment/**"]

    for file_path, _ in walk_files():
        path_str = str(file_path)
        for bad_glob in legacy_globs:
            if fnmatch.fnmatch(path_str, bad_glob):
                bad_paths.append(path_str)
                break

    if bad_paths:
        for bad_path in bad_paths:
            violation(
                f"COVENANT BREACH: Non-canonical path '{bad_path}' — "
                f"should be under infrastructure/gcp/...",
                errors
            )
        print(f"⚠️  Legacy GCP/GKE paths found: {len(bad_paths)}")
    else:
        print("✅ GCP/GKE paths canonical")

    # Generate report artifact
    report = {
        "covenant_version": 1,
        "timestamp": "2025-10-23",
        "root_markdown_count": md_count,
        "root_markdown_violators": violators,
        "duplicate_sets": {
            h: ps for h, ps in duplicates.items() if len(ps) > 1
        },
        "legacy_paths": bad_paths,
        "errors": errors,
        "summary": {
            "total_violations": len(errors),
            "duplicate_groups": dup_count,
            "service_violations": service_errors if 'service_errors' in locals() else 0,
            "legacy_paths": len(bad_paths)
        }
    }

    # Write report
    artifacts_dir = ROOT / "artifacts"
    artifacts_dir.mkdir(exist_ok=True)
    report_path = artifacts_dir / "tem_guardian_report.json"

    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print()
    print(f"📊 Report written to: {report_path}")
    print()

    if errors:
        print("❌ Tem Guardian: COVENANT BREACHED")
        print(f"   {len(errors)} violation(s) detected")
        print("   See artifacts/tem_guardian_report.json for details")
        print()
        print("   Astra inclinant, sed non obligant. 🜂")
        sys.exit(1)

    print("✅ Tem Guardian: ALL GREEN")
    print("   Covenant upheld. Entropy defeated.")
    print()
    print("   Astra inclinant, sed non obligant. 🜂")
    sys.exit(0)

if __name__ == "__main__":
    main()
