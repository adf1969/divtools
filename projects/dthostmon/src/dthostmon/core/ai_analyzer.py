"""
AI analysis module for dthostmon using OpenCode Server
Last Updated: 11/14/2025 12:00:00 PM CDT

Integrates with OpenCode Server for headless access to all available models (Grok, Copilot, etc).
Authentication credentials are loaded from ~/.local/share/opencode/auth.json
"""

import json
import requests
import time
import subprocess
from typing import Dict, List, Optional, Any
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class AIAnalysisError(Exception):
    """Raised when AI analysis fails"""
    pass


class OpenCodeServerManager:
    """Manages OpenCode Server instance"""
    
    def __init__(self, host: str = 'localhost', port: int = 4096):
        """
        Initialize OpenCode Server manager
        
        Args:
            host: Server hostname
            port: Server port
        """
        self.host = host
        self.port = port
        self.base_url = f'http://{host}:{port}'
        self.server_process = None
    
    def start(self) -> bool:
        """
        Start OpenCode server in headless mode
        
        Returns:
            True if server started successfully
        """
        try:
            logger.info(f"Starting OpenCode Server on {self.base_url}")
            
            # Start server in background
            self.server_process = subprocess.Popen(
                ['opencode', 'serve', '--hostname', self.host, '--port', str(self.port)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True  # Detach from parent process
            )
            
            # Wait for server to be ready
            max_retries = 30
            for attempt in range(max_retries):
                try:
                    response = requests.get(f'{self.base_url}/doc', timeout=1)
                    if response.status_code == 200:
                        logger.info("OpenCode Server started successfully")
                        return True
                except Exception:
                    time.sleep(0.5)
                    continue
            
            logger.error("OpenCode Server failed to start within timeout")
            return False
            
        except Exception as e:
            logger.error(f"Failed to start OpenCode Server: {e}")
            return False
    
    def is_running(self) -> bool:
        """Check if server is running"""
        try:
            response = requests.get(f'{self.base_url}/app', timeout=2)
            return response.status_code == 200
        except Exception:
            return False
    
    def get_available_models(self) -> Dict[str, List[str]]:
        """
        Get available models from OpenCode Server
        
        Returns:
            Dict with providers and their models: {'grok': ['grok-beta'], ...}
        """
        try:
            response = requests.get(f'{self.base_url}/config/providers', timeout=10)
            response.raise_for_status()
            
            data = response.json()
            providers = data.get('providers', [])
            
            # Restructure to {provider: [models]}
            models_by_provider = {}
            for provider in providers:
                provider_id = provider.get('id')
                models = provider.get('models', [])
                model_ids = [m.get('id') for m in models if m.get('id')]
                if model_ids:
                    models_by_provider[provider_id] = model_ids
            
            logger.info(f"Available models: {models_by_provider}")
            return models_by_provider
            
        except Exception as e:
            logger.error(f"Failed to get available models: {e}")
            return {}
    
    def analyze_with_model(self, model: str, prompt: str, timeout: int = 60) -> str:
        """
        Send analysis prompt to specified model
        
        Args:
            model: Model ID (e.g., 'grok/grok-beta', 'copilot/gpt-4')
            prompt: Analysis prompt
            timeout: Request timeout in seconds
        
        Returns:
            Model response text
        """
        try:
            # Create session for context
            session_response = requests.post(
                f'{self.base_url}/session',
                json={'title': 'dthostmon log analysis'},
                timeout=10
            )
            session_response.raise_for_status()
            session_id = session_response.json().get('id')
            
            logger.debug(f"Created OpenCode session: {session_id}")
            
            # Send message to model
            message_response = requests.post(
                f'{self.base_url}/session/{session_id}/message',
                json={
                    'content': prompt,
                    'model': model
                },
                timeout=timeout
            )
            message_response.raise_for_status()
            
            message_data = message_response.json()
            
            # Extract response from message
            if isinstance(message_data, dict):
                # Check for parts array
                if 'parts' in message_data:
                    for part in message_data['parts']:
                        if part.get('role') == 'assistant':
                            return part.get('content', '')
                # Check for direct content
                if 'content' in message_data:
                    return message_data['content']
                # Check for message field
                if 'message' in message_data:
                    msg = message_data['message']
                    if isinstance(msg, dict):
                        return msg.get('content', '')
            
            logger.warning(f"Unexpected response format: {message_data}")
            return str(message_data)
            
        except Exception as e:
            raise AIAnalysisError(f"OpenCode Server request failed: {e}")


class AIAnalyzer:
    """AI-powered log analysis using OpenCode Server"""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize AI analyzer
        
        Args:
            config: AI configuration with model settings and OpenCode server config
        """
        self.config = config
        
        # OpenCode Server configuration
        opencode_config = config.get('opencode', {})
        self.server_host = opencode_config.get('host', 'localhost')
        self.server_port = opencode_config.get('port', 4096)
        self.auto_start = opencode_config.get('auto_start', True)
        
        # Model preferences
        self.preferred_models = opencode_config.get('preferred_models', [
            'grok/grok-beta',  # Primary preference
            'anthropic/claude-3-5-sonnet',  # Fallback
            'openai/gpt-4',  # Fallback
            'ollama/llama3.1'  # Local fallback
        ])
        
        # Initialize server manager
        self.server = OpenCodeServerManager(self.server_host, self.server_port)
        self.available_models = {}
    
    def analyze_logs(self, host_info: Dict, logs: List[Dict], 
                     baseline: Optional[Dict] = None) -> Dict[str, Any]:
        """
        Analyze logs using OpenCode Server
        
        Args:
            host_info: Host information
            logs: List of log entries with content
            baseline: Previous baseline for comparison (optional)
        
        Returns:
            Dictionary with analysis results:
                - health_score: 0-100 score
                - anomalies: List of detected anomalies
                - summary: Text summary
                - recommendations: Suggested actions
                - severity: INFO, WARN, or CRITICAL
        """
        # Ensure OpenCode server is running
        if not self.server.is_running():
            if self.auto_start:
                logger.info("OpenCode Server not running. Starting...")
                if not self.server.start():
                    logger.error("Failed to start OpenCode Server")
                    return self._fallback_analysis(host_info, logs)
            else:
                logger.error("OpenCode Server not available and auto_start disabled")
                return self._fallback_analysis(host_info, logs)
        
        # Get available models if not cached
        if not self.available_models:
            self.available_models = self.server.get_available_models()
        
        # Build analysis prompt
        prompt = self._build_analysis_prompt(host_info, logs, baseline)
        
        # Try preferred models in order
        for model_id in self.preferred_models:
            # Check if model is available
            provider, model = model_id.split('/', 1)
            if provider not in self.available_models or model not in self.available_models[provider]:
                logger.debug(f"Model {model_id} not available, skipping")
                continue
            
            try:
                logger.info(f"Attempting analysis with {model_id}")
                response = self.server.analyze_with_model(model_id, prompt, timeout=120)
                logger.info(f"AI analysis completed using {model_id}")
                return self._parse_analysis_response(response)
                
            except Exception as e:
                logger.warning(f"Model {model_id} failed: {e}. Trying next...")
                continue
        
        logger.error("All preferred models unavailable or failed")
        return self._fallback_analysis(host_info, logs)
    
    def _build_analysis_prompt(self, host_info: Dict, logs: List[Dict],
                               baseline: Optional[Dict]) -> str:
        """Build structured prompt for AI analysis"""
        
        # Truncate logs if too large (to avoid token limits)
        max_log_size = 50000  # characters
        total_log_content = ""
        
        for log in logs[:5]:  # Analyze first 5 logs
            if log.get('content'):
                content = log['content']
                if len(total_log_content) + len(content) > max_log_size:
                    # Truncate to fit
                    remaining = max_log_size - len(total_log_content)
                    content = content[:remaining] + "\n... (truncated)"
                    total_log_content += f"\n\n=== {log['path']} ===\n{content}"
                    break
                total_log_content += f"\n\n=== {log['path']} ===\n{content}"
        
        prompt = f"""You are a system administrator analyzing logs from a monitored host.

Host Information:
- Name: {host_info.get('name')}
- Hostname: {host_info.get('hostname')}
- Tags: {', '.join(host_info.get('tags', []))}

Analysis Request:
1. Review the log files below for anomalies, security issues, and system health problems
2. Detect: failed login attempts, permission errors, service crashes, unusual patterns
3. Provide a health score (0-100) where 90-100 = healthy, 70-89 = minor issues, <70 = critical
4. Categorize severity as: INFO, WARN, or CRITICAL

{"Baseline Comparison: Previous log hash was " + baseline.get('content_hash', 'N/A') if baseline else "First monitoring run - no baseline available"}

Log Files:
{total_log_content}

Respond in JSON format:
{{
    "health_score": <0-100>,
    "severity": "<INFO|WARN|CRITICAL>",
    "anomalies": [
        {{"type": "failed_login", "description": "...", "severity": "WARN"}},
        ...
    ],
    "summary": "Brief overview of findings",
    "recommendations": "Suggested actions"
}}
"""
        return prompt
    
    
    def _parse_analysis_response(self, response: str) -> Dict[str, Any]:
        """
        Parse AI model response
        
        Args:
            response: Raw model response
        
        Returns:
            Parsed analysis dictionary
        """
        try:
            # Try to extract JSON from response
            # Look for JSON block in markdown code blocks or raw JSON
            if '```json' in response:
                json_start = response.find('```json') + 7
                json_end = response.find('```', json_start)
                json_str = response[json_start:json_end].strip()
            elif '```' in response:
                json_start = response.find('```') + 3
                json_end = response.find('```', json_start)
                json_str = response[json_start:json_end].strip()
            else:
                # Try to parse entire response as JSON
                json_str = response.strip()
            
            data = json.loads(json_str)
            
            # Validate required fields
            required_fields = ['health_score', 'severity', 'summary']
            for field in required_fields:
                if field not in data:
                    logger.warning(f"Missing field in AI response: {field}")
                    data[field] = self._get_default_value(field)
            
            return data
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            logger.debug(f"Raw response: {response[:500]}")
            
            # Return basic structure with response as summary
            return {
                'health_score': 50,
                'severity': 'WARN',
                'anomalies': [],
                'summary': response[:1000],  # First 1000 chars
                'recommendations': 'Unable to parse structured analysis'
            }
    
    def _get_default_value(self, field: str) -> Any:
        """Get default value for missing field"""
        defaults = {
            'health_score': 50,
            'severity': 'INFO',
            'anomalies': [],
            'summary': 'No analysis available',
            'recommendations': 'No recommendations'
        }
        return defaults.get(field, None)
    
    def _fallback_analysis(self, host_info: Dict, logs: List[Dict]) -> Dict[str, Any]:
        """
        Basic analysis without AI (fallback when all models fail)
        
        Args:
            host_info: Host information
            logs: Log entries
        
        Returns:
            Basic analysis dictionary
        """
        total_lines = sum(log.get('line_count', 0) for log in logs)
        
        return {
            'health_score': 80,  # Assume healthy if no AI analysis
            'severity': 'INFO',
            'anomalies': [],
            'summary': f"Logs retrieved successfully from {host_info.get('name')}. "
                      f"Analyzed {len(logs)} log files with {total_lines} total lines. "
                      f"AI analysis unavailable - manual review recommended.",
            'recommendations': 'Check logs manually for any issues. AI analysis failed.'
        }
