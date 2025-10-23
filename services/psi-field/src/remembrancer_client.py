"""
Remembrancer Client for Ψ-Field Service
---------------------------------------
Client for interacting with Remembrancer cryptographic memory
"""

import os
import json
import hashlib
import logging
import subprocess
import asyncio
from datetime import datetime
from typing import Dict, Any, List, Optional, Union

logger = logging.getLogger(__name__)

# Default settings
DEFAULT_REMEMBRANCER_BIN = "/home/sovereign/vm-spawn/ops/bin/remembrancer"
DEFAULT_REMEMBRANCER_API = "http://remembrancer:8080"

class RemembrancerClient:
    """Client for Remembrancer cryptographic memory service"""
    
    def __init__(
        self, 
        remembrancer_bin: str = None,
        remembrancer_api: str = None,
        use_cli: bool = True,
        use_api: bool = True
    ):
        """Initialize Remembrancer client"""
        self.remembrancer_bin = remembrancer_bin or os.environ.get(
            "REMEMBRANCER_BIN", DEFAULT_REMEMBRANCER_BIN
        )
        self.remembrancer_api = remembrancer_api or os.environ.get(
            "REMEMBRANCER_API", DEFAULT_REMEMBRANCER_API
        )
        self.use_cli = use_cli and os.path.exists(self.remembrancer_bin)
        self.use_api = use_api
        
        if self.use_cli:
            logger.info(f"Remembrancer CLI client initialized: {self.remembrancer_bin}")
        if self.use_api:
            logger.info(f"Remembrancer API client initialized: {self.remembrancer_api}")
        if not (self.use_cli or self.use_api):
            logger.warning("No Remembrancer client available")
    
    async def record(self, data: Dict[str, Any], event_type: str = "psi_state") -> Dict[str, Any]:
        """Record data to Remembrancer"""
        # Create receipt
        timestamp = datetime.utcnow().isoformat()
        receipt = {
            "event": event_type,
            "timestamp": timestamp,
            "data": data
        }
        
        # Calculate SHA-256 hash
        data_str = json.dumps(data, sort_keys=True)
        sha256 = hashlib.sha256(data_str.encode('utf-8')).hexdigest()
        receipt["hash"] = sha256
        
        # Record using CLI if available
        if self.use_cli:
            try:
                result = await self._record_cli(receipt)
                receipt["cli_result"] = result
            except Exception as e:
                logger.error(f"Error recording to Remembrancer CLI: {str(e)}")
        
        # Record using API if available
        if self.use_api:
            try:
                api_result = await self._record_api(receipt)
                receipt["api_result"] = api_result
            except Exception as e:
                logger.error(f"Error recording to Remembrancer API: {str(e)}")
        
        return receipt
    
    async def _record_cli(self, receipt: Dict[str, Any]) -> Dict[str, Any]:
        """Record using Remembrancer CLI"""
        # Create temporary file
        receipt_file = f"/tmp/psi_receipt_{datetime.utcnow().timestamp()}.json"
        with open(receipt_file, 'w') as f:
            json.dump(receipt, f)
        
        # Build command
        cmd = [
            self.remembrancer_bin,
            "record",
            "psi",
            "--component", "psi-field",
            "--evidence", receipt_file,
            "--hash", receipt["hash"],
            "--metadata", json.dumps({
                "event": receipt["event"],
                "k": receipt["data"].get("k", 0),
                "Psi": receipt["data"].get("Psi", 0.0),
                "timestamp": receipt["timestamp"]
            })
        ]
        
        # Execute command
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        # Check result
        if process.returncode != 0:
            logger.error(f"Remembrancer CLI error: {stderr.decode()}")
            raise RuntimeError(f"Remembrancer CLI failed: {stderr.decode()}")
        
        # Parse result
        result = stdout.decode().strip()
        logger.info(f"Remembrancer CLI result: {result}")
        
        # Clean up
        os.unlink(receipt_file)
        
        return {"success": True, "message": result}
    
    async def _record_api(self, receipt: Dict[str, Any]) -> Dict[str, Any]:
        """Record using Remembrancer API"""
        # This would use httpx or aiohttp to call the API
        # For now, this is a placeholder
        return {"success": True, "message": "API not implemented yet"}
    
    async def verify_receipt(self, receipt_hash: str) -> Dict[str, Any]:
        """Verify a receipt in Remembrancer"""
        if self.use_cli:
            cmd = [
                self.remembrancer_bin,
                "verify",
                receipt_hash
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                result = stdout.decode().strip()
                return {"verified": True, "message": result}
            else:
                return {"verified": False, "error": stderr.decode().strip()}
        
        return {"verified": False, "error": "No verification method available"}
    
    async def get_merkle_proof(self, receipt_hash: str) -> Dict[str, Any]:
        """Get Merkle proof for a receipt"""
        if self.use_cli:
            cmd = [
                self.remembrancer_bin,
                "get-proof",
                receipt_hash
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                result = stdout.decode().strip()
                try:
                    proof = json.loads(result)
                    return proof
                except json.JSONDecodeError:
                    return {"error": "Failed to parse proof JSON"}
            else:
                return {"error": stderr.decode().strip()}
        
        return {"error": "No proof method available"}