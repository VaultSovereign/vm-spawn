"""
RabbitMQ Integration for Ψ-Field Service
---------------------------------------
Implements RabbitMQ messaging for telemetry and alerts
"""

import os
import json
import asyncio
import logging
from typing import Dict, Any, Optional, List

# Check if pika is installed
try:
    import pika
    PIKA_AVAILABLE = True
except ImportError:
    PIKA_AVAILABLE = False
    logging.warning("pika package not installed. RabbitMQ functionality disabled.")

# Constants
DEFAULT_RABBIT_URL = "amqp://guest:guest@localhost:5672/"
DEFAULT_EXCHANGE = "swarm"
DEFAULT_AGENT_ID = "psi-field-agent"

class RabbitMQPublisher:
    """RabbitMQ Publisher for PSI Agent messages"""
    
    def __init__(
        self, 
        agent_id: str = None, 
        rabbit_url: str = None, 
        exchange: str = None,
        enabled: bool = True
    ):
        """Initialize the RabbitMQ publisher"""
        self.agent_id = agent_id or os.environ.get("AGENT_ID", DEFAULT_AGENT_ID)
        self.rabbit_url = rabbit_url or os.environ.get("RABBIT_URL", DEFAULT_RABBIT_URL)
        self.exchange = exchange or os.environ.get("RABBIT_EXCHANGE", DEFAULT_EXCHANGE)
        self.enabled = enabled and os.environ.get("RABBIT_ENABLED", "0") == "1" and PIKA_AVAILABLE
        
        self._connection = None
        self._channel = None
        
        if self.enabled:
            self._init_connection()
            logging.info(f"RabbitMQ publisher initialized for agent {self.agent_id}")
        else:
            logging.info("RabbitMQ publisher disabled")
    
    def _init_connection(self):
        """Initialize the RabbitMQ connection"""
        if not self.enabled:
            return
        
        try:
            # Create connection parameters
            params = pika.URLParameters(self.rabbit_url)
            
            # Connect to RabbitMQ
            self._connection = pika.BlockingConnection(params)
            self._channel = self._connection.channel()
            
            # Declare topic exchange
            self._channel.exchange_declare(
                exchange=self.exchange,
                exchange_type='topic',
                durable=True
            )
        except Exception as e:
            logging.error(f"Error connecting to RabbitMQ: {str(e)}")
            self.enabled = False
    
    def publish_telemetry(self, telemetry: Dict[str, Any]):
        """Publish telemetry data to RabbitMQ"""
        if not self.enabled:
            return
        
        try:
            # Create the routing key
            routing_key = f"{self.exchange}.{self.agent_id}.telemetry"
            
            # Add timestamp and agent_id if not present
            if "agent_id" not in telemetry:
                telemetry["agent_id"] = self.agent_id
            
            # Publish message
            self._channel.basic_publish(
                exchange=self.exchange,
                routing_key=routing_key,
                body=json.dumps(telemetry),
                properties=pika.BasicProperties(
                    content_type='application/json',
                    delivery_mode=2  # Make message persistent
                )
            )
            logging.debug(f"Published telemetry to {routing_key}")
        except Exception as e:
            logging.error(f"Error publishing telemetry to RabbitMQ: {str(e)}")
            # Try to reconnect
            self._init_connection()
    
    def publish_guardian_alert(self, alert: Dict[str, Any]):
        """Publish guardian alert to RabbitMQ"""
        if not self.enabled:
            return
        
        try:
            # Create the routing key
            routing_key = "guardian.alerts"
            
            # Add timestamp and agent_id if not present
            if "agent_id" not in alert:
                alert["agent_id"] = self.agent_id
            
            # Publish message
            self._channel.basic_publish(
                exchange=self.exchange,
                routing_key=routing_key,
                body=json.dumps(alert),
                properties=pika.BasicProperties(
                    content_type='application/json',
                    delivery_mode=2,  # Make message persistent
                    priority=9  # High priority for alerts
                )
            )
            logging.info(f"Published guardian alert: {alert}")
        except Exception as e:
            logging.error(f"Error publishing guardian alert to RabbitMQ: {str(e)}")
            # Try to reconnect
            self._init_connection()
    
    def close(self):
        """Close the RabbitMQ connection"""
        if self.enabled and self._connection and self._connection.is_open:
            self._connection.close()
            logging.info("RabbitMQ connection closed")