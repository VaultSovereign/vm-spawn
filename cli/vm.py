#!/usr/bin/env python3
"""Unified VaultMesh Spawn command line interface."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional


@dataclass
class CommandResult:
    """Structured information returned to CLI consumers."""

    action: str
    ok: bool
    payload: Dict[str, Any]


class CLIError(Exception):
    """Raised when the CLI cannot fulfil a request."""


def _emit_table(rows: Iterable[Dict[str, Any]]) -> None:
    rows = list(rows)
    if not rows:
        print("(no results)")
        return

    columns: List[str] = []
    seen = set()
    for row in rows:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                columns.append(key)

    widths = {col: max(len(col), *(len(str(row.get(col, ""))) for row in rows)) for col in columns}
    header = " | ".join(col.ljust(widths[col]) for col in columns)
    separator = "-+-".join("-" * widths[col] for col in columns)
    print(header)
    print(separator)
    for row in rows:
        print(" | ".join(str(row.get(col, "")).ljust(widths[col]) for col in columns))


def _normalize_rows(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, list):
        return [row if isinstance(row, dict) else {"value": row} for row in payload]
    if isinstance(payload, dict):
        for candidate in ("items", "services", "memories", "entries", "rows"):
            value = payload.get(candidate)
            if isinstance(value, list):
                return [row if isinstance(row, dict) else {"value": row} for row in value]
        return [payload]
    return [{"value": payload}]


def emit_output(result: CommandResult, output_format: str) -> None:
    document = {
        "action": result.action,
        "ok": result.ok,
        "timestamp": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "data": result.payload,
    }
    if output_format == "table":
        _emit_table(_normalize_rows(document["data"]))
    else:
        print(json.dumps(document, indent=2, sort_keys=False))


def run_external(command: List[str], profile: Optional[str] = None) -> Dict[str, Any]:
    env = os.environ.copy()
    if profile:
        env["VAULTMESH_PROFILE"] = profile
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
    except FileNotFoundError:
        return {
            "command": command,
            "exit_code": 127,
            "stdout": "",
            "stderr": f"command not found: {command[0]}",
        }

    return {
        "command": command,
        "exit_code": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def handle_spawn_create(args: argparse.Namespace) -> CommandResult:
    command = ["bash", "spawn.sh", args.name, args.type]
    if args.with_mcp:
        command.append("--with-mcp")
    if args.with_mq:
        command.extend(["--with-mq", args.with_mq])
    result = run_external(command, profile=args.profile)
    ok = result["exit_code"] == 0
    return CommandResult(
        action="spawn.create",
        ok=ok,
        payload={
            "profile": args.profile,
            "name": args.name,
            "type": args.type,
            "with_mcp": bool(args.with_mcp),
            "with_mq": args.with_mq,
            "result": result,
        },
    )


def handle_spawn_list(args: argparse.Namespace) -> CommandResult:
    services_dir = Path("services")
    services: List[Dict[str, Any]] = []
    if services_dir.exists():
        for service in sorted(p for p in services_dir.iterdir() if p.is_dir()):
            template = service / "template.json"
            services.append(
                {
                    "name": service.name,
                    "path": str(service),
                    "has_template": template.exists(),
                    "modified": datetime.utcfromtimestamp(service.stat().st_mtime).isoformat() + "Z",
                }
            )
    return CommandResult(
        action="spawn.list",
        ok=True,
        payload={
            "profile": args.profile,
            "count": len(services),
            "services": services,
        },
    )


def handle_spawn_describe(args: argparse.Namespace) -> CommandResult:
    service_path = Path("services") / args.name
    exists = service_path.exists()
    payload: Dict[str, Any] = {
        "profile": args.profile,
        "name": args.name,
        "exists": exists,
    }
    if exists:
        payload.update(
            {
                "path": str(service_path),
                "files": sorted(str(p.relative_to(service_path)) for p in service_path.rglob("*")),
            }
        )
    else:
        payload["message"] = "service not found"
    return CommandResult(action="spawn.describe", ok=exists, payload=payload)


def handle_memory_passthrough(args: argparse.Namespace, command_name: str) -> CommandResult:
    binary = Path("ops/bin/remembrancer")
    if not binary.exists():
        raise CLIError("remembrancer tool not available")

    command = [str(binary), command_name]
    if getattr(args, "memory_id", None):
        command.extend(["--id", args.memory_id])
    if getattr(args, "memory_type", None):
        command.extend(["--type", args.memory_type])
    if getattr(args, "payload", None):
        command.extend(["--payload", args.payload])
    result = run_external(command, profile=args.profile)
    ok = result["exit_code"] == 0
    return CommandResult(
        action=f"memory.{command_name}",
        ok=ok,
        payload={
            "profile": args.profile,
            "result": result,
        },
    )


def handle_memory_query(args: argparse.Namespace) -> CommandResult:
    return handle_memory_passthrough(args, "query")


def handle_memory_record(args: argparse.Namespace) -> CommandResult:
    return handle_memory_passthrough(args, "record")


def handle_memory_timeline(args: argparse.Namespace) -> CommandResult:
    return handle_memory_passthrough(args, "timeline")


def handle_memory_verify(args: argparse.Namespace) -> CommandResult:
    return handle_memory_passthrough(args, "verify")


def handle_audit_verify(args: argparse.Namespace) -> CommandResult:
    binary = Path("ops/bin/remembrancer")
    command = [str(binary), "verify"] if binary.exists() else ["bash", "ops/bin/health-check"]
    result = run_external(command, profile=args.profile)
    ok = result["exit_code"] == 0
    return CommandResult(
        action="audit.verify",
        ok=ok,
        payload={
            "profile": args.profile,
            "result": result,
        },
    )


def handle_audit_report(args: argparse.Namespace) -> CommandResult:
    command = ["bash", "ops/bin/health-check"]
    result = run_external(command, profile=args.profile)
    ok = result["exit_code"] == 0
    return CommandResult(
        action="audit.report",
        ok=ok,
        payload={
            "profile": args.profile,
            "result": result,
        },
    )


def handle_status_show(args: argparse.Namespace) -> CommandResult:
    services_dir = Path("services")
    generators_dir = Path("generators")
    receipts_dir = Path("ops/receipts")
    payload = {
        "profile": args.profile or "default",
        "timestamp": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "services": [
            {
                "name": p.name,
                "path": str(p),
            }
            for p in sorted(services_dir.iterdir())
            if p.is_dir()
        ]
        if services_dir.exists()
        else [],
        "generators": sorted(p.name for p in generators_dir.glob("*.sh")) if generators_dir.exists() else [],
        "receipts_available": receipts_dir.exists(),
    }
    return CommandResult(action="status.show", ok=True, payload=payload)


def handle_configure(args: argparse.Namespace) -> CommandResult:
    if not args.region or not args.remembrancer_endpoint or not args.did_key_id:
        raise CLIError("region, remembrancer-endpoint, and did-key-id are required")

    config_dir = Path.home() / ".vaultmesh"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_path = config_dir / "config.toml"

    federation_endpoints = [endpoint.strip() for endpoint in args.federation_endpoint or [] if endpoint.strip()]
    profile_name = args.profile or "default"
    lines = [
        f"[profiles.{profile_name}]",
        f'region = "{args.region}"',
        f'remembrancer_endpoint = "{args.remembrancer_endpoint}"',
        f'did_key_id = "{args.did_key_id}"',
    ]
    if federation_endpoints:
        joined = ", ".join(f'"{endpoint}"' for endpoint in federation_endpoints)
        lines.append(f"federation_endpoints = [{joined}]")
    content = "\n".join(lines) + "\n"
    config_path.write_text(content)

    payload = {
        "profile": profile_name,
        "path": str(config_path),
        "region": args.region,
        "remembrancer_endpoint": args.remembrancer_endpoint,
        "did_key_id": args.did_key_id,
        "federation_endpoints": federation_endpoints,
    }
    return CommandResult(action="configure", ok=True, payload=payload)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vm",
        description="VaultMesh unified CLI for spawn, memory, audit, and status operations.",
    )
    parser.add_argument("--format", choices=["json", "table"], default="json", help="output format")
    parser.add_argument("--profile", help="active VaultMesh profile", default=None)
    subparsers = parser.add_subparsers(dest="domain")

    # spawn
    spawn_parser = subparsers.add_parser("spawn", help="infrastructure forge operations")
    spawn_sub = spawn_parser.add_subparsers(dest="verb")

    spawn_create = spawn_sub.add_parser("create", help="generate a new service skeleton")
    spawn_create.add_argument("name", help="service name")
    spawn_create.add_argument("--type", default="service", help="service type")
    spawn_create.add_argument("--with-mcp", action="store_true", help="include MCP scaffold")
    spawn_create.add_argument("--with-mq", choices=["rabbitmq", "nats"], help="include message queue client")
    spawn_create.set_defaults(handler=handle_spawn_create)

    spawn_list = spawn_sub.add_parser("list", help="list generated services")
    spawn_list.set_defaults(handler=handle_spawn_list)

    spawn_describe = spawn_sub.add_parser("describe", help="describe a generated service")
    spawn_describe.add_argument("name", help="service name")
    spawn_describe.set_defaults(handler=handle_spawn_describe)

    # memory
    memory_parser = subparsers.add_parser("memory", help="cryptographic memory operations")
    memory_sub = memory_parser.add_subparsers(dest="verb")
    for verb, handler in (
        ("query", handle_memory_query),
        ("record", handle_memory_record),
        ("timeline", handle_memory_timeline),
        ("verify", handle_memory_verify),
    ):
        memory_cmd = memory_sub.add_parser(verb, help=f"remembrancer {verb} command")
        memory_cmd.add_argument("--memory-id", help="memory identifier")
        memory_cmd.add_argument("--memory-type", help="memory type filter")
        if verb == "record":
            memory_cmd.add_argument("--payload", help="memory payload contents")
        memory_cmd.set_defaults(handler=handler)

    # audit
    audit_parser = subparsers.add_parser("audit", help="audit and verification commands")
    audit_sub = audit_parser.add_subparsers(dest="verb")
    audit_verify = audit_sub.add_parser("verify", help="verify anchors and receipts")
    audit_verify.set_defaults(handler=handle_audit_verify)
    audit_report = audit_sub.add_parser("report", help="generate audit report")
    audit_report.set_defaults(handler=handle_audit_report)

    # status
    status_parser = subparsers.add_parser("status", help="platform status commands")
    status_sub = status_parser.add_subparsers(dest="verb")
    status_show = status_sub.add_parser("show", help="display current status summary")
    status_show.set_defaults(handler=handle_status_show)

    # configure
    configure_parser = subparsers.add_parser("configure", help="manage local configuration and profiles")
    configure_parser.add_argument("--region", required=False, help="deployment region for this profile")
    configure_parser.add_argument("--remembrancer-endpoint", required=False, help="remembrancer API endpoint")
    configure_parser.add_argument("--did-key-id", required=False, help="default DID key identifier")
    configure_parser.add_argument(
        "--federation-endpoint",
        action="append",
        help="federation endpoint URL (can be repeated)",
    )
    configure_parser.set_defaults(handler=handle_configure)

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not hasattr(args, "handler"):
        parser.print_help()
        return 1

    try:
        result = args.handler(args)
    except CLIError as exc:
        emit_output(
            CommandResult(action="error", ok=False, payload={"error": str(exc)}),
            getattr(args, "format", "json"),
        )
        return 1

    emit_output(result, args.format)
    return 0 if result.ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
