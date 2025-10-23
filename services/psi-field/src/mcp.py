"""
MCP (JSON-RPC 2.0) Interface for Ψ-Field Service
-----------------------------------------------
Implements a JSON-RPC 2.0 control interface using FastAPI
"""

import json
import logging
from typing import Dict, Any, List, Optional, Callable, Awaitable
from fastapi import Request, HTTPException, Depends, Body, APIRouter
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

class JsonRpcRequest(BaseModel):
    """JSON-RPC 2.0 request model"""
    jsonrpc: str = Field("2.0", description="JSON-RPC version")
    id: Optional[str] = Field(None, description="Request ID")
    method: str = Field(..., description="Method name to call")
    params: Optional[Dict[str, Any]] = Field(None, description="Method parameters")

class JsonRpcResponse(BaseModel):
    """JSON-RPC 2.0 response model"""
    jsonrpc: str = "2.0"
    id: Optional[str] = None
    result: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None

class JsonRpcError(BaseModel):
    """JSON-RPC 2.0 error model"""
    code: int
    message: str
    data: Optional[Any] = None

class MCPTool:
    """Represents a tool in the MCP protocol"""
    def __init__(self, name: str, handler: Callable, description: str, param_schema: Dict):
        self.name = name
        self.handler = handler
        self.description = description
        self.param_schema = param_schema

class MCPServer:
    """JSON-RPC 2.0 server for Ψ-Field control"""
    
    def __init__(self, prefix: str = "/mcp"):
        """Initialize the MCP server"""
        self.prefix = prefix
        self.router = APIRouter(prefix=prefix)
        self.tools: Dict[str, MCPTool] = {}
        
        # Register the endpoint
        self.router.post("", response_model=JsonRpcResponse)(self.handle_request)
    
    def tool(self, name: str = None, description: str = "", param_schema: Dict = None):
        """Decorator to register a tool"""
        def decorator(func):
            tool_name = name or func.__name__
            schema = param_schema or {}
            self.register_tool(tool_name, func, description, schema)
            return func
        return decorator
    
    def register_tool(self, name: str, handler: Callable, description: str = "", param_schema: Dict = None):
        """Register a tool with the MCP server"""
        self.tools[name] = MCPTool(name, handler, description, param_schema or {})
        logger.info(f"Registered MCP tool: {name}")
    
    async def handle_request(self, request: Request):
        """Handle incoming JSON-RPC requests"""
        try:
            body = await request.json()
            rpc_request = JsonRpcRequest(**body)
            
            # Extract request data
            method = rpc_request.method
            params = rpc_request.params or {}
            req_id = rpc_request.id
            
            # Validate method
            if method not in self.tools:
                return JsonRpcResponse(
                    id=req_id,
                    error={"code": -32601, "message": f"Method not found: {method}"}
                )
            
            # Execute the handler
            tool = self.tools[method]
            try:
                result = await tool.handler(**params)
                return JsonRpcResponse(id=req_id, result=result)
            except Exception as e:
                logger.error(f"Error executing {method}: {str(e)}")
                return JsonRpcResponse(
                    id=req_id,
                    error={"code": -32603, "message": f"Internal error: {str(e)}"}
                )
                
        except Exception as e:
            logger.error(f"Error processing MCP request: {str(e)}")
            return JsonRpcResponse(
                id=None,
                error={"code": -32700, "message": f"Parse error: {str(e)}"}
            )