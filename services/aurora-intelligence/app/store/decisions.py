"""
Decision Store - Persist routing decisions for feedback loop

Uses SQLite to store decision traces, enabling:
1. Feedback matching (trace_id → state/action)
2. Observability and debugging
3. Training data collection
"""

import sqlite3
import json
import time
import os
from typing import Dict, Any, Optional
from threading import Lock
from ..config import settings


class DecisionStore:
    """Thread-safe SQLite store for decision traces"""

    _instance = None
    _lock = Lock()

    def __new__(cls):
        """Singleton pattern for global store instance"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        """Initialize database connection and schema"""
        if self._initialized:
            return

        # Ensure data directory exists
        os.makedirs(os.path.dirname(settings.STORE_FILE), exist_ok=True)

        # Connect to SQLite (or create if not exists)
        self.conn = sqlite3.connect(
            settings.STORE_FILE,
            check_same_thread=False
        )
        self.conn.row_factory = sqlite3.Row  # Return rows as dicts

        # Create schema
        self._create_schema()
        self._initialized = True

    def _create_schema(self):
        """Create decision traces table"""
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS traces (
                trace_id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                timestamp REAL NOT NULL,
                state_key TEXT NOT NULL,
                action TEXT NOT NULL,
                chosen TEXT NOT NULL,
                reward REAL,
                next_state_key TEXT,
                feedback_timestamp REAL,
                metadata TEXT
            )
        """)

        # Index for faster lookups
        self.conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_task_id ON traces(task_id)
        """)
        self.conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_timestamp ON traces(timestamp)
        """)

        self.conn.commit()

    def save_trace(
        self,
        trace_id: str,
        task_id: str,
        state_key: str,
        action: str,
        chosen: Dict[str, Any],
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Save decision trace

        Args:
            trace_id: Unique trace identifier
            task_id: Task identifier
            state_key: Discretized state representation
            action: Action taken (candidate index)
            chosen: Selected candidate details
            metadata: Additional metadata
        """
        with self._lock:
            self.conn.execute("""
                INSERT OR REPLACE INTO traces
                (trace_id, task_id, timestamp, state_key, action, chosen, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                trace_id,
                task_id,
                time.time(),
                state_key,
                action,
                json.dumps(chosen),
                json.dumps(metadata or {})
            ))
            self.conn.commit()

    def update_feedback(
        self,
        trace_id: str,
        reward: float,
        next_state_key: str
    ):
        """
        Update trace with feedback

        Args:
            trace_id: Trace identifier
            reward: Computed reward
            next_state_key: Next state representation
        """
        with self._lock:
            self.conn.execute("""
                UPDATE traces
                SET reward = ?, next_state_key = ?, feedback_timestamp = ?
                WHERE trace_id = ?
            """, (reward, next_state_key, time.time(), trace_id))
            self.conn.commit()

    def get_trace(self, trace_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve trace by ID

        Args:
            trace_id: Trace identifier

        Returns:
            Trace dict or None if not found
        """
        with self._lock:
            cursor = self.conn.execute("""
                SELECT * FROM traces WHERE trace_id = ?
            """, (trace_id,))
            row = cursor.fetchone()

            if row is None:
                return None

            return dict(row)

    def get_recent_traces(self, limit: int = 100) -> list:
        """
        Get recent decision traces

        Args:
            limit: Maximum number of traces to return

        Returns:
            List of trace dicts
        """
        with self._lock:
            cursor = self.conn.execute("""
                SELECT * FROM traces
                ORDER BY timestamp DESC
                LIMIT ?
            """, (limit,))
            return [dict(row) for row in cursor.fetchall()]

    def get_stats(self) -> Dict[str, Any]:
        """
        Get store statistics

        Returns:
            Stats dict with counts and metrics
        """
        with self._lock:
            cursor = self.conn.execute("SELECT COUNT(*) FROM traces")
            total_traces = cursor.fetchone()[0]

            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM traces WHERE reward IS NOT NULL
            """)
            traces_with_feedback = cursor.fetchone()[0]

            return {
                "total_traces": total_traces,
                "traces_with_feedback": traces_with_feedback,
                "feedback_rate": traces_with_feedback / total_traces if total_traces > 0 else 0.0,
                "store_file": settings.STORE_FILE,
            }


# Global store instance
store = DecisionStore()
