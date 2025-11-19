"""
SSH connection and remote log retrieval
Last Updated: 11/14/2025 12:00:00 PM CDT

Handles SSH connections to remote hosts and log file retrieval.
"""

import paramiko
import hashlib
import logging
from typing import Dict, List, Optional, Tuple
from pathlib import Path
from datetime import datetime

logger = logging.getLogger(__name__)


class SSHConnectionError(Exception):
    """Raised when SSH connection fails"""
    pass


class LogRetrievalError(Exception):
    """Raised when log retrieval fails"""
    pass


class SSHClient:
    """SSH client for connecting to remote hosts and retrieving logs"""
    
    def __init__(self, hostname: str, port: int, username: str, 
                 key_path: str, timeout: int = 10):
        """
        Initialize SSH client
        
        Args:
            hostname: Target host IP or hostname
            port: SSH port (default 22)
            username: SSH username
            key_path: Path to SSH private key
            timeout: Connection timeout in seconds
        """
        self.hostname = hostname
        self.port = port
        self.username = username
        self.key_path = key_path
        self.timeout = timeout
        self.client: Optional[paramiko.SSHClient] = None
        self.connected = False
    
    def connect(self, retries: int = 3) -> bool:
        """
        Establish SSH connection with retry logic
        
        Args:
            retries: Number of retry attempts
        
        Returns:
            True if connection successful
        
        Raises:
            SSHConnectionError: If connection fails after all retries
        """
        for attempt in range(retries):
            try:
                self.client = paramiko.SSHClient()
                self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                
                # Load private key
                if not Path(self.key_path).exists():
                    raise SSHConnectionError(f"SSH key not found: {self.key_path}")
                
                private_key = paramiko.Ed25519Key.from_private_key_file(self.key_path)
                
                # Connect
                self.client.connect(
                    hostname=self.hostname,
                    port=self.port,
                    username=self.username,
                    pkey=private_key,
                    timeout=self.timeout,
                    look_for_keys=False,
                    allow_agent=False
                )
                
                self.connected = True
                logger.info(f"SSH connected to {self.username}@{self.hostname}:{self.port}")
                return True
                
            except (paramiko.AuthenticationException, 
                    paramiko.SSHException, 
                    OSError) as e:
                logger.warning(f"SSH connection attempt {attempt + 1}/{retries} failed: {e}")
                if attempt == retries - 1:
                    raise SSHConnectionError(
                        f"Failed to connect to {self.hostname} after {retries} attempts: {e}"
                    )
                
                # Exponential backoff: 1s, 2s, 4s
                import time
                time.sleep(2 ** attempt)
        
        return False
    
    def disconnect(self):
        """Close SSH connection"""
        if self.client:
            self.client.close()
            self.connected = False
            logger.debug(f"SSH disconnected from {self.hostname}")
    
    def execute_command(self, command: str, timeout: int = 30) -> Tuple[str, str, int]:
        """
        Execute remote command
        
        Args:
            command: Shell command to execute
            timeout: Command execution timeout
        
        Returns:
            Tuple of (stdout, stderr, exit_code)
        
        Raises:
            SSHConnectionError: If not connected
        """
        if not self.connected or not self.client:
            raise SSHConnectionError("Not connected to remote host")
        
        try:
            stdin, stdout, stderr = self.client.exec_command(command, timeout=timeout)
            exit_code = stdout.channel.recv_exit_status()
            
            stdout_str = stdout.read().decode('utf-8', errors='replace')
            stderr_str = stderr.read().decode('utf-8', errors='replace')
            
            return stdout_str, stderr_str, exit_code
            
        except Exception as e:
            logger.error(f"Command execution failed: {e}")
            raise LogRetrievalError(f"Failed to execute command: {e}")
    
    def retrieve_log_file(self, log_path: str) -> Dict[str, any]:
        """
        Retrieve log file contents from remote host
        
        Args:
            log_path: Absolute path to log file on remote host
        
        Returns:
            Dictionary with:
                - path: Log file path
                - content: File contents
                - hash: SHA256 hash of content
                - line_count: Number of lines
                - file_size: Size in bytes
                - retrieved_at: Timestamp
        
        Raises:
            LogRetrievalError: If file cannot be retrieved
        """
        if not self.connected:
            raise SSHConnectionError("Not connected to remote host")
        
        try:
            # Check if file exists and is readable
            check_cmd = f"test -r '{log_path}' && echo 'OK' || echo 'FAIL'"
            stdout, stderr, exit_code = self.execute_command(check_cmd)
            
            if 'FAIL' in stdout or exit_code != 0:
                logger.warning(f"Log file not accessible: {log_path}")
                return {
                    'path': log_path,
                    'content': None,
                    'hash': None,
                    'line_count': 0,
                    'file_size': 0,
                    'retrieved_at': datetime.utcnow(),
                    'error': 'File not accessible'
                }
            
            # Retrieve file contents
            cat_cmd = f"cat '{log_path}'"
            stdout, stderr, exit_code = self.execute_command(cat_cmd)
            
            if exit_code != 0:
                raise LogRetrievalError(f"Failed to read {log_path}: {stderr}")
            
            content = stdout
            content_hash = hashlib.sha256(content.encode('utf-8')).hexdigest()
            line_count = len(content.splitlines())
            file_size = len(content.encode('utf-8'))
            
            logger.debug(f"Retrieved {log_path}: {file_size} bytes, {line_count} lines")
            
            return {
                'path': log_path,
                'content': content,
                'hash': content_hash,
                'line_count': line_count,
                'file_size': file_size,
                'retrieved_at': datetime.utcnow(),
                'error': None
            }
            
        except Exception as e:
            logger.error(f"Failed to retrieve {log_path}: {e}")
            raise LogRetrievalError(f"Log retrieval failed for {log_path}: {e}")
    
    def retrieve_multiple_logs(self, log_paths: List[str]) -> List[Dict[str, any]]:
        """
        Retrieve multiple log files
        
        Args:
            log_paths: List of log file paths
        
        Returns:
            List of log data dictionaries
        """
        results = []
        
        for log_path in log_paths:
            try:
                # Support glob patterns for user home directories
                if '*' in log_path:
                    # Expand glob pattern
                    expand_cmd = f"ls {log_path} 2>/dev/null"
                    stdout, stderr, exit_code = self.execute_command(expand_cmd)
                    
                    if exit_code == 0 and stdout.strip():
                        expanded_paths = stdout.strip().split('\n')
                        for expanded_path in expanded_paths:
                            log_data = self.retrieve_log_file(expanded_path.strip())
                            results.append(log_data)
                    else:
                        logger.debug(f"No files matched pattern: {log_path}")
                else:
                    log_data = self.retrieve_log_file(log_path)
                    results.append(log_data)
                    
            except LogRetrievalError as e:
                logger.warning(f"Skipping {log_path}: {e}")
                results.append({
                    'path': log_path,
                    'content': None,
                    'hash': None,
                    'line_count': 0,
                    'file_size': 0,
                    'retrieved_at': datetime.utcnow(),
                    'error': str(e)
                })
        
        return results
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()
