#!/usr/bin/env python3
"""
dthostmon Configuration Sync Tool
Syncs Docker site configurations from dthm-*.yaml and .env files into dthostmon.yaml

Usage:
    python3 dthostmon_sync_config.py <config_file> <sites_dir>

Environment Variables:
    DEBUG_MODE: Set to '1' to enable debug output
    VALIDATE: Set to '1' to enable validation checks
"""

import sys
import yaml
import os
import re
from pathlib import Path


def log_debug(msg):
    """Print debug message if DEBUG_MODE is enabled"""
    if os.environ.get('DEBUG_MODE') == '1':
        print(f"[DEBUG] {msg}", file=sys.stderr)


def expand_env_vars(value, env_dict, immediate=True):
    """
    Expand environment variables in a string.
    
    Args:
        value: String value that may contain env vars
        env_dict: Dictionary of environment variables
        immediate: If True, expand ${VAR}. If False, keep ${VAR} as-is but expand ${{VAR}} to ${VAR}
    
    Returns:
        String with env vars expanded according to rules
    """
    if not isinstance(value, str):
        return value
    
    # Handle ${{VAR}} - convert to ${VAR} (deferred expansion)
    value = re.sub(r'\$\{\{([^}]+)\}\}', r'${\1}', value)
    
    if immediate:
        # Handle ${VAR} - expand immediately
        def replace_var(match):
            var_name = match.group(1)
            return env_dict.get(var_name, match.group(0))
        
        value = re.sub(r'\$\{([^}]+)\}', replace_var, value)
    
    return value


def process_yaml_value(value, env_dict):
    """Recursively process YAML values to expand env vars."""
    if isinstance(value, dict):
        return {k: process_yaml_value(v, env_dict) for k, v in value.items()}
    elif isinstance(value, list):
        return [process_yaml_value(item, env_dict) for item in value]
    elif isinstance(value, str):
        return expand_env_vars(value, env_dict, immediate=True)
    else:
        return value


def parse_env_file(env_file):
    """Parse .env file and extract DTHM_* variables."""
    config = {}
    
    if not os.path.exists(env_file):
        return config
    
    log_debug(f"Parsing env file: {env_file}")
    
    with open(env_file, 'r') as f:
        for line in f:
            line = line.strip()
            
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Parse KEY=VALUE
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                
                # Remove quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                elif value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
                
                # Only process DTHM_* variables
                if key.startswith('DTHM_'):
                    config[key] = value
                    log_debug(f"  Found {key}={value}")
    
    return config


def env_to_config(env_vars, prefix):
    """
    Convert DTHM_* environment variables to configuration dict.
    
    Args:
        env_vars: Dict of DTHM_* environment variables
        prefix: Either 'DTHM_SITE_' or 'DTHM_HOST_'
    
    Returns:
        Dict with configuration values
    """
    config = {}
    
    for key, value in env_vars.items():
        if not key.startswith(prefix):
            continue
        
        # Remove prefix to get config key
        config_key = key[len(prefix):].lower()
        
        # Handle boolean values
        if value.lower() in ('true', 'yes', '1'):
            config[config_key] = True
        elif value.lower() in ('false', 'no', '0'):
            config[config_key] = False
        # Handle numeric values
        elif value.isdigit():
            config[config_key] = int(value)
        # Handle comma-delimited lists
        elif ',' in value:
            config[config_key] = [item.strip() for item in value.split(',')]
        # String value
        else:
            config[config_key] = value
    
    return config


def parse_dthm_yaml(yaml_file, env_dict):
    """Parse dthm-*.yaml file with env var expansion."""
    if not os.path.exists(yaml_file):
        return {}
    
    log_debug(f"Parsing YAML file: {yaml_file}")
    
    with open(yaml_file, 'r') as f:
        content = f.read()
    
    # First pass: expand ${{VAR}} to ${VAR}
    content = re.sub(r'\$\{\{([^}]+)\}\}', r'${\1}', content)
    
    # Second pass: expand ${VAR} with current env
    def replace_var(match):
        var_name = match.group(1)
        return env_dict.get(var_name, match.group(0))
    
    content = re.sub(r'\$\{([^}]+)\}', replace_var, content)
    
    # Parse YAML
    config = yaml.safe_load(content)
    
    return config or {}


def merge_configs(*configs):
    """Merge multiple configuration dicts, later ones override earlier."""
    result = {}
    
    for config in configs:
        if not config:
            continue
        
        for key, value in config.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                # Recursive merge for nested dicts
                result[key] = merge_configs(result[key], value)
            else:
                # Override with new value
                result[key] = value
    
    return result


def scan_docker_sites(sites_dir):
    """
    Scan Docker sites directory for sites and hosts.
    
    Returns:
        Dict with structure: {
            'site_name': {
                'config': {...},
                'hosts': {
                    'host_name': {...}
                }
            }
        }
    """
    sites = {}
    sites_path = Path(sites_dir)
    
    if not sites_path.exists():
        log_debug(f"Sites directory not found: {sites_dir}")
        return sites
    
    # Get all environment variables for expansion
    env_dict = dict(os.environ)
    
    # Iterate through site directories
    for site_dir in sorted(sites_path.iterdir()):
        if not site_dir.is_dir():
            continue
        
        site_name = site_dir.name
        
        # SKIP: s00-* folders (contain apps/services, not hosts)
        if site_name.startswith('s00-'):
            log_debug(f"Skipping s00-* folder (apps, not hosts): {site_name}")
            continue
        
        log_debug(f"Processing site: {site_name}")
        
        # Initialize site entry
        sites[site_name] = {
            'config': {},
            'hosts': {}
        }
        
        # Parse site-level .env file
        site_env_file = site_dir / f".env.{site_name}"
        site_env_vars = parse_env_file(str(site_env_file))
        site_env_config = env_to_config(site_env_vars, 'DTHM_SITE_')
        
        # Parse site-level dthm-site.yaml
        site_yaml_file = site_dir / "dthm-site.yaml"
        site_yaml_config = parse_dthm_yaml(str(site_yaml_file), env_dict)
        
        # Merge site configurations (env vars override YAML)
        sites[site_name]['config'] = merge_configs(site_yaml_config, site_env_config)
        
        # Scan for host directories
        for host_dir in sorted(site_dir.iterdir()):
            if not host_dir.is_dir():
                continue
            
            host_name = host_dir.name
            
            # SKIP: Hidden directories (.) and other special dirs
            if host_name.startswith('.'):
                log_debug(f"  Skipping hidden directory: {host_name}")
                continue
            
            log_debug(f"  Processing host: {host_name}")
            
            # Parse host-level .env file
            host_env_file = host_dir / f".env.{host_name}"
            host_env_vars = parse_env_file(str(host_env_file))
            host_env_config = env_to_config(host_env_vars, 'DTHM_HOST_')
            
            # Parse host-level dthm-<hostname>.yaml file
            host_yaml_file = host_dir / f"dthm-{host_name}.yaml"
            host_yaml_config = parse_dthm_yaml(str(host_yaml_file), env_dict)
            
            # Merge host configurations (env vars override YAML)
            host_config = merge_configs(host_yaml_config, host_env_config)
            
            # Set the host name (use actual hostname from directory)
            host_config['name'] = host_name
            
            sites[site_name]['hosts'][host_name] = host_config
    
    return sites


def update_dthostmon_config(config_file, discovered_sites):
    """Update dthostmon.yaml with discovered configuration."""
    
    # Load current config
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f) or {}
    
    # Ensure sites section exists
    if 'sites' not in config:
        config['sites'] = {}
    
    # Ensure hosts section exists
    if 'hosts' not in config:
        config['hosts'] = []
    
    # Update/add sites
    for site_name, site_data in discovered_sites.items():
        if site_data['config']:
            if site_name not in config['sites']:
                log_debug(f"Adding new site: {site_name}")
            else:
                log_debug(f"Updating existing site: {site_name}")
            
            config['sites'][site_name] = site_data['config']
        
        # Update/add hosts
        for host_name, host_config in site_data['hosts'].items():
            # Check if host already exists
            existing_host = None
            for idx, host in enumerate(config['hosts']):
                # Skip if host is not a dict (malformed entry)
                if not isinstance(host, dict):
                    continue
                if host.get('name') == host_name:
                    existing_host = idx
                    break
            
            if existing_host is not None:
                log_debug(f"Updating existing host: {host_name}")
                # Merge with existing config
                config['hosts'][existing_host] = merge_configs(
                    config['hosts'][existing_host],
                    host_config
                )
            else:
                log_debug(f"Adding new host: {host_name}")
                config['hosts'].append(host_config)
    
    return config


def validate_config(cfg):
    """Validate configuration and return (has_error, has_warn)"""
    has_error = False
    has_warn = False
    
    # Validate hosts
    hosts = cfg.get('hosts', [])
    for idx, host in enumerate(hosts):
        # Skip if host is not a dict (malformed entry - could be string or other type)
        if not isinstance(host, dict):
            print(f"[WARN] Host at index {idx} is not a dict, skipping: {host}", file=sys.stderr)
            has_warn = True
            continue
        
        name = host.get('name')
        if not name:
            print(f"[ERROR] Host at index {idx} missing 'name'", file=sys.stderr)
            has_error = True
        hn = host.get('hostname')
        if not hn:
            print(f"[ERROR] Host '{name or idx}' missing 'hostname'", file=sys.stderr)
            has_error = True
        port = host.get('port')
        if port is not None:
            try:
                if int(port) <= 0:
                    print(f"[ERROR] Host '{name or idx}' has invalid port: {port}", file=sys.stderr)
                    has_error = True
            except Exception:
                print(f"[ERROR] Host '{name or idx}' has non-numeric port: {port}", file=sys.stderr)
                has_error = True
        # tags must be list if present
        tags = host.get('tags')
        if tags is not None and not isinstance(tags, list):
            print(f"[WARN] Host '{name or idx}' tags should be a list, got: {tags}", file=sys.stderr)
            has_warn = True
    
    # Validate sites
    sites = cfg.get('sites', {})
    for site_name, site in sites.items():
        # Skip if site is not a dict (malformed entry)
        if not isinstance(site, dict):
            print(f"[WARN] Site '{site_name}' is not a dict, skipping: {site}", file=sys.stderr)
            has_warn = True
            continue
        tags = site.get('tags')
        if tags is not None and not isinstance(tags, list):
            print(f"[WARN] Site '{site_name}' tags should be a list, got: {tags}", file=sys.stderr)
            has_warn = True
    
    return has_error, has_warn


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 dthostmon_sync_config.py <config_file> <sites_dir>", file=sys.stderr)
        sys.exit(1)
    
    config_file = sys.argv[1]
    sites_dir = sys.argv[2]
    
    # Scan Docker sites directory
    discovered_sites = scan_docker_sites(sites_dir)
    
    # Print summary
    total_hosts = sum(len(site['hosts']) for site in discovered_sites.values())
    print(f"Discovered {len(discovered_sites)} sites and {total_hosts} hosts", file=sys.stderr)
    
    # List all discovered files in TEST mode
    if os.environ.get('TEST_MODE') == '1':
        print("\n=== Discovered Configuration Files ===", file=sys.stderr)
        for site_name, site_data in discovered_sites.items():
            print(f"\nSite: {site_name}", file=sys.stderr)
            site_dir = Path(sites_dir) / site_name
            
            # Check for site-level files
            site_env = site_dir / f".env.{site_name}"
            site_yaml = site_dir / "dthm-site.yaml"
            
            if site_env.exists():
                print(f"  ✓ {site_env}", file=sys.stderr)
            if site_yaml.exists():
                print(f"  ✓ {site_yaml}", file=sys.stderr)
            
            # Check for host-level files
            for host_name in site_data['hosts'].keys():
                host_dir = site_dir / host_name
                host_env = host_dir / f".env.{host_name}"
                host_yaml = host_dir / f"dthm-{host_name}.yaml"
                
                print(f"  Host: {host_name}", file=sys.stderr)
                if host_env.exists():
                    print(f"    ✓ {host_env}", file=sys.stderr)
                if host_yaml.exists():
                    print(f"    ✓ {host_yaml}", file=sys.stderr)
        print("\n======================================\n", file=sys.stderr)
    
    # Update configuration
    updated_config = update_dthostmon_config(config_file, discovered_sites)
    
    # Validation step if requested
    if os.environ.get('VALIDATE', '0') in ('1', 'true', 'True'):
        has_error, has_warn = validate_config(updated_config)
        if has_error:
            print('[ERROR] Validation failed - errors found', file=sys.stderr)
            # Still print YAML for preview
            yaml.dump(updated_config, sys.stdout, default_flow_style=False, sort_keys=False)
            sys.exit(2)
        elif has_warn:
            print('[WARN] Validation completed with warnings', file=sys.stderr)
        else:
            print('[INFO] Validation passed', file=sys.stderr)
    
    # Write updated config to stdout
    yaml.dump(updated_config, sys.stdout, default_flow_style=False, sort_keys=False)


if __name__ == '__main__':
    main()
