"""
Environment variable loading utilities for divtools Python applications.

This module provides Python equivalents to bash load_env_files() function,
allowing Python apps to load environment variables from standard divtools locations.

Uses python-dotenv library for reliable .env file parsing.

Environment variable loading order (later overrides earlier):
1. Shared: {DOCKERDIR}/s00-shared/.env.s00-shared (common vars for all sites)
2. Site: {DOCKERDIR}/sites/{SITE_NAME}/.env.{SITE_NAME} (site-specific vars)
3. Host: {DOCKERDIR}/sites/{SITE_NAME}/{HOSTNAME}/.env.{HOSTNAME} (host-specific vars)

Where DOCKERDIR is typically: /home/divix/divtools/docker
"""

import os
from pathlib import Path
from typing import Dict, Tuple, Optional

from dotenv import dotenv_values


def _get_docker_dir() -> Optional[Path]:
    """
    Determine the docker directory path.
    
    Checks in order:
    1. $DOCKER_DIR environment variable
    2. $DOCKERDIR environment variable  
    3. {DIVTOOLS}/docker (standard location)
    
    Returns:
        Path to docker directory, or None if not found
    """
    # Check environment variables first
    docker_dir = os.environ.get("DOCKER_DIR") or os.environ.get("DOCKERDIR")
    if docker_dir:
        path = Path(docker_dir).expanduser().resolve()
        if path.exists():
            return path
    
    # Try standard divtools locations
    divtools_root = _get_divtools_root()
    if divtools_root:
        docker_path = divtools_root / "docker"
        if docker_path.exists():
            return docker_path
    
    return None


def load_divtools_env_files(debug: bool = False) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Load environment variables from standard divtools configuration files.
    
    Mirrors the behavior of bash load_env_files() from divtools/.bash_profile.
    Uses python-dotenv library for reliable .env file parsing.
    
    Args:
        debug: If True, print detailed debug messages for each file attempted
        
    Returns:
        Tuple[Dict[str, str], Dict[str, str]]: A tuple of (loaded_vars, failed_files)
            - loaded_vars: Dictionary of all loaded environment variables
            - failed_files: Dictionary of files that were expected but not found
                           (for debugging, not an error - files are optional)
    
    Example:
        >>> env_vars, failed = load_divtools_env_files()
        >>> print(f"Site name: {env_vars.get('SITE_NAME', 'Not set')}")
        >>> print(f"Realm: {env_vars.get('ADS_REALM', 'Not set')}")
    
    Notes:
        - Files are loaded in order, with later files overriding earlier ones
        - Uses python-dotenv library for robust .env parsing
        - Loads from $DOCKERDIR/sites directory structure
        - Returns successfully loaded variables even if some files don't exist
    """
    
    loaded_vars = {}
    failed_files = {}
    
    # Determine docker directory path
    docker_dir = _get_docker_dir()
    if not docker_dir:
        if debug:
            print("[DEBUG] load_divtools_env_files: Could not determine DOCKER directory path")
        return loaded_vars, {"root": "Could not determine DOCKER directory path"}
    
    if debug:
        print(f"[DEBUG] load_divtools_env_files: Using DOCKER directory: {docker_dir}")
    
    # 1. Load shared env file (s00-shared)
    shared_file = docker_dir / "sites" / "s00-shared" / ".env.s00-shared"
    if debug:
        print(f"[DEBUG] load_divtools_env_files: Attempting to load {shared_file}")
    
    if shared_file.exists():
        vars_from_file = dotenv_values(shared_file)
        loaded_vars.update(vars_from_file)
        if debug:
            print(f"[DEBUG] load_divtools_env_files: ✓ Loaded {len(vars_from_file)} variables from {shared_file}")
    else:
        failed_files["shared"] = str(shared_file)
        if debug:
            print(f"[DEBUG] load_divtools_env_files: ✗ File not found (optional): {shared_file}")
    
    # Get SITE_NAME and HOSTNAME for site/host-specific files
    site_name = loaded_vars.get("SITE_NAME") or os.environ.get("SITE_NAME")
    hostname = os.environ.get("HOSTNAME", "")
    
    if debug:
        print(f"[DEBUG] load_divtools_env_files: SITE_NAME={site_name}, HOSTNAME={hostname}")
    
    if not site_name:
        # Can't load site/host files without SITE_NAME
        if debug:
            print(f"[DEBUG] load_divtools_env_files: SITE_NAME not set, skipping site/host-specific files")
        return loaded_vars, {**failed_files, "site_specific": "SITE_NAME not set"}
    
    # 2. Load site env file
    site_file = docker_dir / "sites" / site_name / f".env.{site_name}"
    if debug:
        print(f"[DEBUG] load_divtools_env_files: Attempting to load {site_file}")
    
    if site_file.exists():
        vars_from_file = dotenv_values(site_file)
        loaded_vars.update(vars_from_file)
        if debug:
            print(f"[DEBUG] load_divtools_env_files: ✓ Loaded {len(vars_from_file)} variables from {site_file}")
    else:
        failed_files["site"] = str(site_file)
        if debug:
            print(f"[DEBUG] load_divtools_env_files: ✗ File not found (optional): {site_file}")
    
    # 3. Load host-specific env file
    if hostname:
        host_file = (
            docker_dir / "sites" / site_name / hostname / 
            f".env.{hostname}"
        )
        if debug:
            print(f"[DEBUG] load_divtools_env_files: Attempting to load {host_file}")
        
        if host_file.exists():
            vars_from_file = dotenv_values(host_file)
            loaded_vars.update(vars_from_file)
            if debug:
                print(f"[DEBUG] load_divtools_env_files: ✓ Loaded {len(vars_from_file)} variables from {host_file}")
        else:
            failed_files["host"] = str(host_file)
            if debug:
                print(f"[DEBUG] load_divtools_env_files: ✗ File not found (optional): {host_file}")
    
    if debug:
        print(f"[DEBUG] load_divtools_env_files: Total variables loaded: {len(loaded_vars)}")
        # Show all loaded variables
        for key in sorted(loaded_vars.keys()):
            # Don't print sensitive values
            value = loaded_vars[key]
            if any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'TOKEN', 'CREDENTIAL']):
                value = '*' * min(len(value), 12) if value else '(empty)'
            print(f"[DEBUG]   {key}={value}")
    
    return loaded_vars, failed_files


def _get_divtools_root(debug: bool = False) -> Optional[Path]:
    """
    Determine the divtools root directory.
    
    Checks in order:
    1. DIVTOOLS environment variable
    2. /opt/divtools (production path)
    3. ~/divtools (development path)
    
    Args:
        debug: If True, print messages about path detection
    
    Returns:
        Path | None: Path to divtools root, or None if not found
    """
    
    # Check DIVTOOLS env var
    divtools_env = os.environ.get("DIVTOOLS")
    if divtools_env:
        path = Path(divtools_env)
        if path.is_dir():
            if debug:
                print(f"[DEBUG] _get_divtools_root: Using DIVTOOLS env var: {path}")
            return path
        elif debug:
            print(f"[DEBUG] _get_divtools_root: DIVTOOLS env var set but not a directory: {divtools_env}")
    
    # Check production path
    prod_path = Path("/opt/divtools")
    if prod_path.is_dir():
        if debug:
            print(f"[DEBUG] _get_divtools_root: Found production path: {prod_path}")
        return prod_path
    elif debug:
        print(f"[DEBUG] _get_divtools_root: Production path not found: {prod_path}")
    
    # Check development path
    dev_path = Path.home() / "divtools"
    if dev_path.is_dir():
        if debug:
            print(f"[DEBUG] _get_divtools_root: Found development path: {dev_path}")
        return dev_path
    elif debug:
        print(f"[DEBUG] _get_divtools_root: Development path not found: {dev_path}")
    
    if debug:
        print(f"[DEBUG] _get_divtools_root: ERROR - Could not find DIVTOOLS in any location")
    return None
