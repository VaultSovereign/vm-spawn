#!/usr/bin/env python3
"""
Nonce replay protection cache helper for Aurora gateway.
Provides Redis-backed nonce validation with 24h TTL.
"""

import os
import sys
import time
from typing import Optional, Tuple

try:
    import redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    print("[warning] redis-py not installed; using in-memory cache (dev only)", file=sys.stderr)


class NonceCache:
    """Thread-safe nonce replay protection with TTL."""

    def __init__(self, redis_url: Optional[str] = None, ttl_seconds: int = 86400):
        """
        Initialize nonce cache.

        Args:
            redis_url: Redis connection URL (e.g., redis://localhost:6379/0)
                      If None, uses REDIS_URL env var or falls back to in-memory
            ttl_seconds: Nonce TTL (default: 24h)
        """
        self.ttl_seconds = ttl_seconds
        self.redis_url = redis_url or os.environ.get("REDIS_URL")

        if self.redis_url and REDIS_AVAILABLE:
            try:
                self.redis = redis.from_url(self.redis_url, decode_responses=True)
                self.redis.ping()
                self.backend = "redis"
                print(f"[nonce-cache] Connected to Redis: {self.redis_url}", file=sys.stderr)
            except Exception as e:
                print(f"[nonce-cache] Redis connection failed: {e}", file=sys.stderr)
                print("[nonce-cache] Falling back to in-memory cache", file=sys.stderr)
                self.redis = None
                self.backend = "memory"
                self._memory_cache = {}
        else:
            self.redis = None
            self.backend = "memory"
            self._memory_cache = {}
            if not REDIS_AVAILABLE:
                print("[nonce-cache] Using in-memory cache (install redis-py for production)", file=sys.stderr)

    def check_and_set(self, nonce: str) -> Tuple[bool, str]:
        """
        Check if nonce exists, and set it if not (atomic operation).

        Returns:
            (allowed, reason) tuple
            - allowed=True if nonce is fresh (not seen before)
            - allowed=False if nonce is a replay
        """
        if not nonce or len(nonce) < 8:
            return False, "invalid nonce (too short)"

        key = f"nonce:{nonce}"

        if self.backend == "redis" and self.redis:
            try:
                # SET NX (set if not exists) with expiration
                result = self.redis.set(key, "1", ex=self.ttl_seconds, nx=True)
                if result:
                    return True, "ok"
                else:
                    return False, "replay attack (nonce seen before)"
            except Exception as e:
                print(f"[nonce-cache] Redis error: {e}", file=sys.stderr)
                return False, f"cache error: {e}"
        else:
            # In-memory cache (dev only, not distributed)
            current_time = time.time()

            # Cleanup expired entries (simple TTL)
            expired_keys = [k for k, (_, exp_time) in self._memory_cache.items() if current_time > exp_time]
            for k in expired_keys:
                del self._memory_cache[k]

            if key in self._memory_cache:
                return False, "replay attack (nonce seen before)"

            self._memory_cache[key] = ("1", current_time + self.ttl_seconds)
            return True, "ok"

    def clear(self, pattern: str = "nonce:*") -> int:
        """
        Clear nonces matching pattern (admin operation).

        Returns:
            Number of keys cleared
        """
        if self.backend == "redis" and self.redis:
            try:
                keys = self.redis.keys(pattern)
                if keys:
                    return self.redis.delete(*keys)
                return 0
            except Exception as e:
                print(f"[nonce-cache] Clear error: {e}", file=sys.stderr)
                return 0
        else:
            count = 0
            # Simple glob-style matching for memory cache
            prefix = pattern.replace("*", "")
            keys_to_delete = [k for k in self._memory_cache.keys() if k.startswith(prefix)]
            for k in keys_to_delete:
                del self._memory_cache[k]
                count += 1
            return count

    def stats(self) -> dict:
        """Get cache statistics."""
        if self.backend == "redis" and self.redis:
            try:
                info = self.redis.info("stats")
                return {
                    "backend": "redis",
                    "total_keys": self.redis.dbsize(),
                    "hits": info.get("keyspace_hits", 0),
                    "misses": info.get("keyspace_misses", 0),
                }
            except Exception as e:
                return {"backend": "redis", "error": str(e)}
        else:
            return {
                "backend": "memory",
                "total_keys": len(self._memory_cache),
                "warning": "in-memory cache is not distributed",
            }


# CLI for testing
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Nonce cache helper")
    parser.add_argument("command", choices=["check", "clear", "stats"], help="Command to run")
    parser.add_argument("--nonce", help="Nonce to check (for check command)")
    parser.add_argument("--redis-url", help="Redis URL (default: REDIS_URL env var)")
    args = parser.parse_args()

    cache = NonceCache(redis_url=args.redis_url)

    if args.command == "check":
        if not args.nonce:
            print("Error: --nonce required for check command", file=sys.stderr)
            sys.exit(1)
        allowed, reason = cache.check_and_set(args.nonce)
        print(f"Nonce: {args.nonce}")
        print(f"Allowed: {allowed}")
        print(f"Reason: {reason}")
        sys.exit(0 if allowed else 1)

    elif args.command == "clear":
        count = cache.clear()
        print(f"Cleared {count} nonce entries")

    elif args.command == "stats":
        stats = cache.stats()
        import json
        print(json.dumps(stats, indent=2))
