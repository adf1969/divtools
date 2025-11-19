"""
Pushover Alert Integration for dthostmon
Last Updated: 1/16/2025 1:30:00 PM CST

Implements FR-ALERT-002: Sends abbreviated alerts via Pushover for critical issues.
"""

import requests
import logging
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class PushoverError(Exception):
    """Raised when Pushover sending fails"""
    pass


class PushoverAlert:
    """Pushover notification sender for critical alerts"""
    
    # Priority levels
    PRIORITY_LOWEST = -2
    PRIORITY_LOW = -1
    PRIORITY_NORMAL = 0
    PRIORITY_HIGH = 1
    PRIORITY_EMERGENCY = 2
    
    def __init__(self, api_token: str, user_key: str, enabled: bool = True):
        """
        Initialize Pushover alert sender
        
        Args:
            api_token: Pushover application API token
            user_key: Pushover user/group key
            enabled: Whether Pushover alerts are enabled
        """
        self.api_token = api_token
        self.user_key = user_key
        self.enabled = enabled
        self.api_url = "https://api.pushover.net/1/messages.json"
    
    def send_alert(self, title: str, message: str, priority: int = PRIORITY_HIGH,
                   url: Optional[str] = None, url_title: Optional[str] = None) -> bool:
        """
        Send Pushover notification
        
        Args:
            title: Notification title
            message: Notification message (max 1024 chars)
            priority: Priority level (-2 to 2)
            url: Optional supplementary URL
            url_title: Optional title for the URL
        
        Returns:
            True if notification sent successfully
        
        Raises:
            PushoverError: If notification sending fails
        """
        if not self.enabled:
            logger.info("Pushover alerts disabled - skipping notification")
            return True
        
        if not self.api_token or not self.user_key:
            logger.error("Pushover API token or user key not configured")
            return False
        
        # Truncate message if too long
        if len(message) > 1024:
            message = message[:1021] + "..."
        
        payload = {
            'token': self.api_token,
            'user': self.user_key,
            'title': title,
            'message': message,
            'priority': priority,
            'html': 1  # Enable HTML formatting
        }
        
        if url:
            payload['url'] = url
            if url_title:
                payload['url_title'] = url_title
        
        try:
            logger.debug(f"Sending Pushover notification: {title}")
            response = requests.post(self.api_url, data=payload, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('status') == 1:
                    logger.info(f"Pushover notification sent successfully: {title}")
                    return True
                else:
                    logger.error(f"Pushover API error: {result.get('errors', 'Unknown error')}")
                    raise PushoverError(f"Pushover API error: {result.get('errors')}")
            else:
                logger.error(f"Pushover HTTP error {response.status_code}: {response.text}")
                raise PushoverError(f"HTTP {response.status_code}: {response.text}")
        
        except requests.exceptions.Timeout:
            logger.error("Pushover notification timed out")
            raise PushoverError("Request timed out")
        
        except requests.exceptions.RequestException as e:
            logger.error(f"Pushover notification failed: {e}")
            raise PushoverError(f"Request failed: {e}")
    
    def send_monitoring_alert(self, monitoring_run: Dict, host_info: Dict) -> bool:
        """
        Send monitoring alert for critical issues
        
        Only sends alerts for WARN and CRITICAL severity levels.
        
        Args:
            monitoring_run: Monitoring run data
            host_info: Host information
        
        Returns:
            True if notification sent successfully
        """
        if not self.enabled:
            return True
        
        alert_level = monitoring_run.get('alert_level', 'INFO')
        
        # Only send Pushover for WARN and CRITICAL
        if alert_level not in ['WARN', 'CRITICAL']:
            logger.debug(f"Skipping Pushover alert for {alert_level} level")
            return True
        
        host_name = host_info.get('name', 'Unknown Host')
        health_score = monitoring_run.get('health_score', 0)
        anomalies = monitoring_run.get('anomalies_detected', 0)
        changes = monitoring_run.get('changes_detected', 0)
        
        # Determine priority
        priority = self.PRIORITY_EMERGENCY if alert_level == 'CRITICAL' else self.PRIORITY_HIGH
        
        # Create alert title
        emoji = '🚨' if alert_level == 'CRITICAL' else '⚠️'
        title = f"{emoji} {alert_level}: {host_name}"
        
        # Create abbreviated message
        message = f"""<b>Host:</b> {host_info.get('hostname')}
<b>Health Score:</b> {health_score}/100
<b>Anomalies:</b> {anomalies}
<b>Changes:</b> {changes}"""
        
        # Add brief AI summary if available (first 200 chars)
        if monitoring_run.get('ai_summary'):
            summary = monitoring_run['ai_summary']
            if len(summary) > 200:
                summary = summary[:197] + "..."
            message += f"\n\n{summary}"
        
        message += "\n\n<i>Detailed email alert sent separately</i>"
        
        try:
            return self.send_alert(
                title=title,
                message=message,
                priority=priority
            )
        except PushoverError as e:
            logger.error(f"Failed to send Pushover alert: {e}")
            return False
    
    def test_connection(self) -> bool:
        """
        Test Pushover configuration by sending a test message
        
        Returns:
            True if test successful
        """
        if not self.enabled:
            logger.info("Pushover disabled - skipping test")
            return True
        
        try:
            return self.send_alert(
                title="dthostmon Test",
                message="Pushover integration is configured correctly!",
                priority=self.PRIORITY_LOW
            )
        except PushoverError as e:
            logger.error(f"Pushover test failed: {e}")
            return False
