#!/usr/bin/env python3
"""
WASM Policy Host Adapter for vault-law policies.
Provides simple JSON-in/JSON-out interface to WASM policy modules.

Supports both Wasmtime (default) and Wasmer runtimes.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple

try:
    from wasmtime import Store, Module, Instance, Func, FuncType, ValType
    WASMTIME_AVAILABLE = True
except ImportError:
    WASMTIME_AVAILABLE = False

try:
    from wasmer import engine, Store as WasmerStore, Module as WasmerModule, Instance as WasmerInstance
    from wasmer_compiler_cranelift import Compiler
    WASMER_AVAILABLE = True
except ImportError:
    WASMER_AVAILABLE = False

if not WASMTIME_AVAILABLE and not WASMER_AVAILABLE:
    print("[error] No WASM runtime available", file=sys.stderr)
    print("[error] Install: pip install wasmtime  (recommended)", file=sys.stderr)
    print("[error]      or: pip install wasmer wasmer-compiler-cranelift", file=sys.stderr)
    sys.exit(1)


class PolicyHostAdapter:
    """Host adapter for WASM policy execution."""

    def __init__(self, wasm_path: str, runtime: str = "wasmtime"):
        """
        Initialize policy host adapter.

        Args:
            wasm_path: Path to WASM policy module
            runtime: "wasmtime" or "wasmer" (default: wasmtime)
        """
        self.wasm_path = Path(wasm_path)
        if not self.wasm_path.exists():
            raise FileNotFoundError(f"WASM policy not found: {wasm_path}")

        self.runtime = runtime.lower()

        if self.runtime == "wasmtime" and WASMTIME_AVAILABLE:
            self._init_wasmtime()
        elif self.runtime == "wasmer" and WASMER_AVAILABLE:
            self._init_wasmer()
        else:
            raise ValueError(f"Runtime '{runtime}' not available or not supported")

    def _init_wasmtime(self):
        """Initialize Wasmtime runtime."""
        self.store = Store()
        self.module = Module.from_file(self.store.engine, str(self.wasm_path))
        self.instance = Instance(self.store, self.module, [])

        # Get the authorize_json export
        self.authorize_json = self.instance.exports(self.store)["authorize_json"]
        print(f"[policy-host] Loaded WASM policy via Wasmtime: {self.wasm_path}", file=sys.stderr)

    def _init_wasmer(self):
        """Initialize Wasmer runtime."""
        store = WasmerStore(engine.JIT(Compiler))
        wasm_bytes = self.wasm_path.read_bytes()
        module = WasmerModule(store, wasm_bytes)
        self.instance = WasmerInstance(module)

        # Get the authorize_json export
        self.authorize_json = self.instance.exports.authorize_json
        print(f"[policy-host] Loaded WASM policy via Wasmer: {self.wasm_path}", file=sys.stderr)

    def authorize(self, treaty: Dict, order: Dict, acc: Dict) -> Tuple[bool, str]:
        """
        Execute policy authorization.

        Args:
            treaty: Treaty configuration dict
            order: Order request dict
            acc: Accumulator state dict

        Returns:
            (allow, reason) tuple
        """
        # Build input JSON
        input_data = {
            "treaty": treaty,
            "order": order,
            "acc": acc
        }
        input_json = json.dumps(input_data).encode('utf-8')

        try:
            if self.runtime == "wasmtime":
                result_ptr = self._call_wasmtime(input_json)
            else:
                result_ptr = self._call_wasmer(input_json)

            # Read result from WASM memory
            # Note: This is simplified; real implementation needs memory export access
            # For now, assume the policy returns a JSON string pointer
            # TODO: Implement proper memory read from WASM linear memory

            # Temporary: Return mock result
            # In production, you'd read from WASM memory at result_ptr
            result = {"allow": True, "reason": "WASM call succeeded (memory read not implemented)"}

            return result.get("allow", False), result.get("reason", "unknown")

        except Exception as e:
            return False, f"policy execution error: {e}"

    def _call_wasmtime(self, input_bytes: bytes) -> int:
        """Call WASM function via Wasmtime."""
        # Allocate memory in WASM for input
        # TODO: Implement proper memory allocation and pointer passing
        # For now, just call the function with dummy ptr/len
        ptr = 0
        length = len(input_bytes)
        result = self.authorize_json(self.store, ptr, length)
        return result

    def _call_wasmer(self, input_bytes: bytes) -> int:
        """Call WASM function via Wasmer."""
        # Allocate memory in WASM for input
        # TODO: Implement proper memory allocation and pointer passing
        ptr = 0
        length = len(input_bytes)
        result = self.authorize_json(ptr, length)
        return result


# CLI for testing
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="WASM policy host adapter")
    parser.add_argument("wasm_file", help="Path to WASM policy module")
    parser.add_argument("input_json", help="Path to input JSON file (treaty, order, acc)")
    parser.add_argument("--runtime", choices=["wasmtime", "wasmer"], default="wasmtime",
                       help="WASM runtime to use")
    args = parser.parse_args()

    # Load input
    try:
        with open(args.input_json) as f:
            input_data = json.load(f)
    except Exception as e:
        print(f"Error loading input JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Validate input structure
    if not all(k in input_data for k in ["treaty", "order", "acc"]):
        print("Error: Input JSON must contain 'treaty', 'order', and 'acc' fields", file=sys.stderr)
        sys.exit(1)

    # Execute policy
    try:
        adapter = PolicyHostAdapter(args.wasm_file, runtime=args.runtime)
        allow, reason = adapter.authorize(
            input_data["treaty"],
            input_data["order"],
            input_data["acc"]
        )

        print(json.dumps({
            "allow": allow,
            "reason": reason
        }, indent=2))

        sys.exit(0 if allow else 1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
