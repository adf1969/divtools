"""
Configuration management for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

Handles YAML configuration loading with environment variable substitution.
"""

import os
import re
import yaml
from typing import Any, Dict, List, Optional
from pathlib import Path
from dotenv import load_dotenv
import logging

logger = logging.getLogger(__name__)


class ConfigurationError(Exception):
    """Raised when configuration is invalid or missing"""
    pass


class Config:
    """Configuration manager for dthostmon"""
    
    def __init__(self, config_path: str = None, env_file: str = None):
        """
        Initialize configuration
        
        Args:
            config_path: Path to YAML config file (default: config/dthostmon.yaml)
            env_file: Path to .env file (default: .env in project root)
        """
        # Load environment variables first
        if env_file and Path(env_file).exists():
            load_dotenv(env_file)
            logger.info(f"Loaded environment variables from {env_file}")
        else:
            load_dotenv()  # Load from default .env location
        
        # Determine config file path
        if config_path is None:
            # Try to find config relative to project root
            possible_paths = [
                Path("config/dthostmon.yaml"),
                Path("/opt/dthostmon/config/dthostmon.yaml"),
                Path("../config/dthostmon.yaml")
            ]
            for path in possible_paths:
                if path.exists():
                    config_path = str(path)
                    break
            
            if config_path is None:
                raise ConfigurationError("No configuration file found. Checked: " + 
                                       ", ".join(str(p) for p in possible_paths))
        
        self.config_path = Path(config_path)
        if not self.config_path.exists():
            raise ConfigurationError(f"Configuration file not found: {config_path}")
        
        # Load and parse YAML
        with open(self.config_path, 'r') as f:
            raw_yaml = f.read()
        
        # Substitute environment variables
        substituted_yaml = self._substitute_env_vars(raw_yaml)
        
        # Parse YAML
        try:
            self.data = yaml.safe_load(substituted_yaml)
        except yaml.YAMLError as e:
            raise ConfigurationError(f"Invalid YAML syntax: {e}")
        
        logger.info(f"Configuration loaded from {config_path}")
        self._validate()
    
    def _substitute_env_vars(self, yaml_content: str) -> str:
        """
        Replace ${VAR_NAME} with environment variable values
        
        Args:
            yaml_content: Raw YAML content with placeholders
        
        Returns:
            YAML content with substituted values
        """
        pattern = re.compile(r'\$\{([A-Za-z0-9_]+)\}')
        
        def replacer(match):
            var_name = match.group(1)
            value = os.getenv(var_name)
            if value is None:
                logger.warning(f"Environment variable {var_name} not set, using empty string")
                return ""
            return value
        
        return pattern.sub(replacer, yaml_content)
    
    def _validate(self):
        """Validate required configuration sections exist"""
        required_sections = ['global', 'database', 'email', 'ssh', 'hosts']
        missing = [section for section in required_sections if section not in self.data]
        
        if missing:
            raise ConfigurationError(f"Missing required configuration sections: {', '.join(missing)}")
        
        # Validate hosts section
        if not isinstance(self.data['hosts'], list) or len(self.data['hosts']) == 0:
            raise ConfigurationError("Configuration must include at least one host in 'hosts' section")
        
        logger.debug("Configuration validation passed")
    
    def get(self, key_path: str, default: Any = None) -> Any:
        """
        Get configuration value using dot notation
        
        Args:
            key_path: Dot-separated path (e.g., 'database.host')
            default: Default value if key not found
        
        Returns:
            Configuration value or default
        
        Example:
            config.get('database.host')  # Returns database host
            config.get('email.smtp_port', 587)  # Returns port or 587
        """
        keys = key_path.split('.')
        value = self.data
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value
    
    @staticmethod
    def _to_bool(value: Any) -> bool:
        """
        Convert various string/value representations to boolean
        
        Args:
            value: Value to convert (bool, str, or other)
        
        Returns:
            Boolean value
        """
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            return value.lower() in ('true', '1', 'yes', 'on')
        return bool(value)
    
    @property
    def hosts(self) -> List[Dict[str, Any]]:
        """Get list of monitored hosts"""
        return [h for h in self.data['hosts'] if h.get('enabled', True)]
    
    def get_host_report_frequency(self, host: Dict[str, Any]) -> str:
        """
        Get report frequency for a host using hierarchical override logic.
        Host > Site > Global
        
        Args:
            host: Host configuration dictionary
        
        Returns:
            Report frequency string (e.g., 'daily', 'weekly', 'hourly')
        """
        # Host level override (highest priority)
        if 'report_frequency' in host and host['report_frequency']:
            return host['report_frequency']
        
        # Site level override
        if 'site' in host and host['site']:
            site_config = self.get(f"sites.{host['site']}", {})
            if 'report_frequency' in site_config and site_config['report_frequency']:
                return site_config['report_frequency']
        
        # Global default (lowest priority)
        return self.get('global.report_frequency', 'daily')
    
    def get_resource_thresholds(self, site: str = None) -> Dict[str, tuple]:
        """
        Get resource usage thresholds for reports.
        
        Args:
            site: Optional site identifier for site-specific thresholds
        
        Returns:
            Dictionary with threshold ranges for health, info, warning, critical
            Format: {'health': (0, 30), 'info': (31, 60), 'warning': (61, 89), 'critical': (90, 100)}
        """
        # Try site-specific thresholds first
        if site:
            thresholds = self.get(f"sites.{site}.resource_thresholds")
            if thresholds:
                return self._parse_thresholds(thresholds)
        
        # Fall back to global thresholds
        thresholds = self.get('global.resource_thresholds', {
            'health': '0-30',
            'info': '31-60',
            'warning': '61-89',
            'critical': '90-100'
        })
        return self._parse_thresholds(thresholds)
    
    def _parse_thresholds(self, threshold_config: Dict[str, str]) -> Dict[str, tuple]:
        """
        Parse threshold configuration strings to tuples.
        
        Args:
            threshold_config: Dict with strings like '0-30', '90-100'
        
        Returns:
            Dict with tuples like (0, 30), (90, 100)
        """
        result = {}
        for level, range_str in threshold_config.items():
            if isinstance(range_str, str) and '-' in range_str:
                low, high = range_str.split('-')
                result[level] = (int(low), int(high))
            elif isinstance(range_str, (list, tuple)) and len(range_str) == 2:
                result[level] = tuple(range_str)
        return result
    
    @property
    def sites(self) -> List[str]:
        """
        Get list of unique sites from configured hosts.
        
        Returns:
            List of site identifiers
        """
        sites = set()
        for host in self.hosts:
            if 'site' in host and host['site']:
                sites.add(host['site'])
        return sorted(list(sites))
    
    @property
    def database_url(self) -> str:
        """Build PostgreSQL connection URL"""
        db = self.data['database']
        return f"postgresql://{db['user']}:{db['password']}@{db['host']}:{db['port']}/{db['name']}"
    
    @property
    def log_level(self) -> str:
        """Get logging level"""
        return self.get('global.log_level', 'INFO').upper()
    
    def print_config(self, mask_secrets: bool = True):
        """
        Print current configuration (for debugging)
        
        Args:
            mask_secrets: Whether to mask sensitive values
        """
        import copy
        config_copy = copy.deepcopy(self.data)
        
        if mask_secrets:
            # Mask sensitive fields
            sensitive_keys = ['password', 'api_key', 'token', 'secret']
            
            def mask_dict(d):
                if isinstance(d, dict):
                    for key, value in d.items():
                        if any(s in key.lower() for s in sensitive_keys):
                            d[key] = "***MASKED***"
                        else:
                            mask_dict(value)
                elif isinstance(d, list):
                    for item in d:
                        mask_dict(item)
            
            mask_dict(config_copy)
        
        print(yaml.dump(config_copy, default_flow_style=False, indent=2))
